package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"github.com/charmbracelet/bubbles/progress"
	"github.com/charmbracelet/bubbles/spinner"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

type Task struct {
	Category string
	Software string
	Path     string
}

type model struct {
	tasks        []Task
	index        int
	width        int
	height       int
	spinner      spinner.Model
	progress     progress.Model
	taskProgress float64
	currentPkg   string
	done         bool
	finalizing   bool
	err          error
}

type taskCompletedMsg struct{ err error }
type progressTickMsg float64
type pkgUpdateMsg string
type finalDoneMsg struct{}

var (
	currentTaskStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("211"))
	doneStyle        = lipgloss.NewStyle().Margin(1, 2)
	checkMark        = lipgloss.NewStyle().Foreground(lipgloss.Color("42")).SetString("✓")
	errorMark        = lipgloss.NewStyle().Foreground(lipgloss.Color("196")).SetString("✗")
	helpStyle        = lipgloss.NewStyle().Foreground(lipgloss.Color("241"))
	completedStyle   = lipgloss.NewStyle().Bold(true)

	pacmanRegex = regexp.MustCompile(`\(([0-9]+/[0-9]+)\) (?:installing|upgrading) ([^ ]+)`)
)

func newModel() model {
	p := progress.New(
		progress.WithGradient("#5A56E0", "#EE6FF8"),
		progress.WithWidth(40),
		progress.WithoutPercentage(),
	)
	s := spinner.New()
	s.Spinner = spinner.Dot
	s.Style = lipgloss.NewStyle().Foreground(lipgloss.Color("63"))

	tasks := []Task{
		{Category: "System Initialization", Software: "Iceunit Packages", Path: "scripts/00-system-init.sh"},
		{Category: "Code Vault Creation", Software: "LUKS2 Vault", Path: "scripts/00-setup-vault.sh"},
		{Category: "Thermal Setup", Software: "mbpfan", Path: "scripts/01-thermal-setup.sh"},
		{Category: "Wi-Fi Firmware", Software: "BCM4377b Firmware", Path: "scripts/02-wifi-firmware.sh"},
		{Category: "System Optimisation", Software: "TLP & Kernel Tweaks", Path: "scripts/03-optimise.sh"},
		{Category: "Bootloader Configuration", Software: "Limine & rEFInd", Path: "scripts/04-bootloader.sh"},
		{Category: "Unlock Code Vault", Software: "Mounting /root/Code", Path: "scripts/05-mount-vault.sh"},
		{Category: "AI Dev Workstation", Software: "Aider, Docker & Ollama", Path: "workstation/00-ai-dev-workstation.sh"},
		{Category: "GNOME Productivity", Software: "Productivity Tweaks", Path: "workstation/10-gnome-productivity.sh"},
		{Category: "DevOps Tools", Software: "Kubectl & Terraform", Path: "workstation/20-devops-tools.sh"},
		{Category: "Security Tools", Software: "Gitleaks & SOPS", Path: "workstation/30-security-tools.sh"},
		{Category: "Dotfiles Link", Software: "Symbolic Links", Path: "workstation/40-dotfiles-link.sh"},
	}

	return model{
		tasks:    tasks,
		spinner:  s,
		progress: p,
	}
}

func (m model) Init() tea.Cmd {
	return tea.Batch(
		m.spinner.Tick,
		executeTask(m.tasks[m.index]),
		m.tickProgress(),
	)
}

func (m model) tickProgress() tea.Cmd {
	return tea.Tick(time.Millisecond*50, func(t time.Time) tea.Msg {
		return progressTickMsg(0.005)
	})
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		return m, nil

	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c", "esc", "q":
			return m, tea.Quit
		}

	case progressTickMsg:
		if !m.done && m.err == nil {
			increment := float64(msg)
			if m.taskProgress > 0.8 {
				increment *= 0.5
			}
			m.taskProgress += increment
			if m.taskProgress > 0.99 {
				m.taskProgress = 0.99
			}
			totalPercent := (float64(m.index) + m.taskProgress) / float64(len(m.tasks))
			return m, tea.Batch(m.progress.SetPercent(totalPercent), m.tickProgress())
		}
		return m, nil

	case pkgUpdateMsg:
		m.currentPkg = string(msg)
		return m, nil

	case taskCompletedMsg:
		if msg.err != nil {
			m.err = msg.err
			return m, tea.Sequence(
				tea.Printf("%s %s %s", errorMark, completedStyle.Render(m.tasks[m.index].Category), helpStyle.Render("("+msg.err.Error()+")")),
				tea.Quit,
			)
		}

		task := m.tasks[m.index]
		m.index++
		m.taskProgress = 0
		m.currentPkg = ""

		if m.index < len(m.tasks) {
			totalPercent := float64(m.index) / float64(len(m.tasks))
			return m, tea.Batch(
				m.progress.SetPercent(totalPercent),
				tea.Printf("%s %s", checkMark, completedStyle.Render(task.Category)),
				executeTask(m.tasks[m.index]),
			)
		} else {
			m.finalizing = true
			return m, tea.Batch(
				m.progress.SetPercent(1.0),
				tea.Printf("%s %s", checkMark, completedStyle.Render(task.Category)),
				tea.Tick(time.Millisecond*500, func(t time.Time) tea.Msg {
					return finalDoneMsg{}
				}),
			)
		}

	case finalDoneMsg:
		m.done = true
		return m, tea.Quit

	case spinner.TickMsg:
		var cmd tea.Cmd
		m.spinner, cmd = m.spinner.Update(msg)
		return m, cmd

	case progress.FrameMsg:
		newModel, cmd := m.progress.Update(msg)
		if pm, ok := newModel.(progress.Model); ok {
			m.progress = pm
		}
		return m, cmd
	}
	return m, nil
}

func (m model) View() string {
	if m.err != nil {
		return ""
	}

	if m.done {
		return doneStyle.Render(fmt.Sprintf("%s Successfully configured %d Iceunit modules\n", checkMark, len(m.tasks)))
	}

	n := len(m.tasks)
	w := lipgloss.Width(fmt.Sprintf("%d", n))

	displayIndex := m.index
	if displayIndex > n {
		displayIndex = n
	}
	pkgCount := helpStyle.Render(fmt.Sprintf(" %*d/%*d", w, displayIndex, w, n))

	spin := m.spinner.View() + " "
	prog := m.progress.View()
	cellsAvail := max(0, m.width-lipgloss.Width(spin+prog+pkgCount))

	taskIdx := m.index
	if taskIdx >= n {
		taskIdx = n - 1
	}

	software := m.tasks[taskIdx].Software
	if m.currentPkg != "" {
		software = m.currentPkg
	}

	info := lipgloss.NewStyle().MaxWidth(cellsAvail).Render("Installing " + currentTaskStyle.Render(software))

	cellsRemaining := max(0, m.width-lipgloss.Width(spin+info+prog+pkgCount))
	gap := strings.Repeat(" ", cellsRemaining)

	return spin + info + gap + prog + pkgCount
}

var pInstance *tea.Program

func executeTask(task Task) tea.Cmd {
	return func() tea.Msg {
		absPath, _ := filepath.Abs(filepath.Join("..", task.Path))
		args := append([]string{absPath}, os.Args[1:]...)
		cmd := exec.Command("bash", args...)
		cmd.Env = os.Environ()

		stdout, _ := cmd.StdoutPipe()
		stderr, _ := cmd.StderrPipe()

		if err := cmd.Start(); err != nil {
			return taskCompletedMsg{err: err}
		}

		var stderrLog strings.Builder

		// Stream output
		go func() {
			reader := io.MultiReader(stdout, stderr)
			scanner := bufio.NewScanner(reader)
			for scanner.Scan() {
				line := scanner.Text()
				// Log to stderr buffer for error reporting
				stderrLog.WriteString(line + "\n")

				matches := pacmanRegex.FindStringSubmatch(line)
				if len(matches) > 2 && pInstance != nil {
					pInstance.Send(pkgUpdateMsg(fmt.Sprintf("%s %s", matches[2], matches[1])))
				}
			}
		}()

		err := cmd.Wait()
		if err != nil {
			var errLines []string
			allLines := strings.Split(strings.TrimSpace(stderrLog.String()), "\n")
			for _, line := range allLines {
				if strings.Contains(strings.ToLower(line), "error:") {
					errLines = append(errLines, strings.TrimSpace(line))
				}
			}
			errMsg := err.Error()
			if len(errLines) > 0 {
				// Take last 2 unique error lines if possible
				errMsg = errLines[len(errLines)-1]
			} else if len(allLines) > 0 {
				errMsg = fmt.Sprintf("%v: %s", err, allLines[len(allLines)-1])
			}
			return taskCompletedMsg{err: fmt.Errorf("%s", errMsg)}
		}
		return taskCompletedMsg{err: nil}
	}
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func main() {
	m := newModel()
	pInstance = tea.NewProgram(m)
	if _, err := pInstance.Run(); err != nil {
		fmt.Println("Error:", err)
		os.Exit(1)
	}
}
