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
	"sync"
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
	Weight   float64 // Relative duration weight for progress bar accuracy
}

type model struct {
	tasks        []Task
	totalWeight  float64
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
	projectRoot  string
}

// ringLog is a fixed-capacity ring buffer for capturing recent output lines.
// It prevents unbounded memory growth when scripts emit large volumes of output.
type ringLog struct {
	mu    sync.Mutex
	lines []string
	cap   int
	count int
}

func newRingLog(capacity int) *ringLog {
	return &ringLog{lines: make([]string, capacity), cap: capacity}
}

func (r *ringLog) Add(line string) {
	r.mu.Lock()
	r.lines[r.count%r.cap] = line
	r.count++
	r.mu.Unlock()
}

// Lines returns all captured lines in chronological order.
func (r *ringLog) Lines() []string {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.count == 0 {
		return nil
	}
	n := r.count
	if n > r.cap {
		n = r.cap
	}
	result := make([]string, n)
	start := 0
	if r.count > r.cap {
		start = r.count % r.cap
	}
	for i := range n {
		result[i] = r.lines[(start+i)%r.cap]
	}
	return result
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

	root, _ := resolveProjectRoot()

	// Weights reflect approximate relative duration of each task.
	// Heavy package installs get higher weight; quick config scripts get lower.
	tasks := []Task{
		{Category: "System Initialization", Software: "Iceunit Packages", Path: "scripts/00-system-init.sh", Weight: 5.0},
		{Category: "Code Vault Creation", Software: "LUKS2 Vault", Path: "scripts/00-setup-vault.sh", Weight: 1.0},
		{Category: "Thermal Setup", Software: "mbpfan", Path: "scripts/01-thermal-setup.sh", Weight: 2.0},
		{Category: "Wi-Fi Firmware", Software: "BCM4377b Firmware", Path: "scripts/02-wifi-firmware.sh", Weight: 1.0},
		{Category: "System Optimisation", Software: "TLP & Kernel Tweaks", Path: "scripts/03-optimise.sh", Weight: 2.0},
		{Category: "Bootloader Configuration", Software: "Limine & rEFInd", Path: "scripts/04-bootloader.sh", Weight: 1.0},
		{Category: "Unlock Code Vault", Software: "Mounting ~/Code", Path: "scripts/05-mount-vault.sh", Weight: 0.5},
		{Category: "Application Suite", Software: "Browsers, Media & Tools", Path: "scripts/07-install-apps.sh", Weight: 4.0},
		{Category: "Periodic Maintenance", Software: "TRIM, Cache & Journal", Path: "scripts/08-maintenance.sh", Weight: 2.0},
		{Category: "Desktop Foundation", Software: "GNOME, Fonts & Timers", Path: "workstation/05-desktop-base.sh", Weight: 3.0},
		{Category: "AI Dev Workstation", Software: "Aider, Docker & Ollama", Path: "workstation/00-ai-dev-workstation.sh", Weight: 3.0},
		{Category: "GNOME Productivity", Software: "Productivity Tweaks", Path: "workstation/10-gnome-productivity.sh", Weight: 1.0},
		{Category: "DevOps Tools", Software: "Kubectl & Terraform", Path: "workstation/20-devops-tools.sh", Weight: 3.0},
		{Category: "Security Tools", Software: "Gitleaks & SOPS", Path: "workstation/30-security-tools.sh", Weight: 2.0},
		{Category: "Dotfiles Link", Software: "Symbolic Links", Path: "workstation/40-dotfiles-link.sh", Weight: 0.5},
		{Category: "Mise Plugins", Software: "Ollama, Claude & Droid", Path: "workstation/50-mise-plugins.sh", Weight: 2.0},
	}

	// Pre-compute total weight for progress bar calculation
	var totalWeight float64
	for _, t := range tasks {
		totalWeight += t.Weight
	}

	return model{
		tasks:       tasks,
		totalWeight: totalWeight,
		spinner:     s,
		progress:    p,
		projectRoot: root,
	}
}

func (m model) Init() tea.Cmd {
	return tea.Batch(
		m.spinner.Tick,
		executeTask(m.tasks[m.index], m.projectRoot),
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
			totalPercent := m.weightedProgress()
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
			totalPercent := m.weightedProgress()
			return m, tea.Batch(
				m.progress.SetPercent(totalPercent),
				tea.Printf("%s %s", checkMark, completedStyle.Render(task.Category)),
				executeTask(m.tasks[m.index], m.projectRoot),
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
		progressModel, cmd := m.progress.Update(msg)
		m.progress = progressModel.(progress.Model)
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

// weightedProgress returns the overall progress [0.0, 1.0] based on task weights.
// Heavier tasks (e.g. package installs) consume more of the bar than quick config scripts.
func (m model) weightedProgress() float64 {
	var completed float64
	for i := 0; i < m.index && i < len(m.tasks); i++ {
		completed += m.tasks[i].Weight
	}
	if m.index < len(m.tasks) {
		completed += m.tasks[m.index].Weight * m.taskProgress
	}
	if m.totalWeight == 0 {
		return 0
	}
	return completed / m.totalWeight
}

// checkT2Hardware verifies this is a T2 MacBook before starting the installer.
// CachyOS does not tag kernels with "t2" — we detect the apple_bce module instead.
func checkT2Hardware() error {
	out, err := lsmodCmd()
	if err != nil {
		// lsmod failed; skip the check gracefully (e.g. in containers)
		return nil
	}
	if !strings.Contains(string(out), "apple_bce") {
		return fmt.Errorf(
			"apple_bce kernel module not loaded.\n" +
				"  This installer is designed for T2 MacBooks (MacBookAir9,1).\n" +
				"  If you are on the correct hardware, try: sudo modprobe apple_bce\n" +
				"  To skip this check, set SKIP_T2_CHECK=1",
		)
	}
	return nil
}

// resolveProjectRoot returns the project root directory.
// It resolves relative to the executable's location (installer/ → ../)
// rather than the current working directory, making it robust regardless
// of where the binary is invoked from.
func resolveProjectRoot() (string, error) {
	exe, err := osExecutable()
	if err != nil {
		// Fallback to CWD-based resolution (original behaviour)
		return filepath.Abs("..")
	}
	exe, err = filepath.EvalSymlinks(exe)
	if err != nil {
		return filepath.Abs("..")
	}
	// exe is inside installer/ — go up one level to project root
	return filepath.Dir(filepath.Dir(exe)), nil
}

var (
	pInstance *tea.Program
	// Test hooks for dependency injection
	osExecutable = os.Executable
	lsmodCmd     = func() ([]byte, error) { return exec.Command("lsmod").Output() }
)


func executeTask(task Task, root string) tea.Cmd {
	return func() tea.Msg {
		absPath := filepath.Join(root, task.Path)
		args := append([]string{absPath}, os.Args[1:]...)
		cmd := exec.Command("bash", args...)
		cmd.Env = os.Environ()

		stdout, _ := cmd.StdoutPipe()
		stderr, _ := cmd.StderrPipe()

		if err := cmd.Start(); err != nil {
			return taskCompletedMsg{err: err}
		}

		log := newRingLog(100)
		var wg sync.WaitGroup
		wg.Add(2)

		// Scan a pipe concurrently — avoids the sequential io.MultiReader deadlock
		scanPipe := func(pipe io.ReadCloser) {
			defer wg.Done()
			scanner := bufio.NewScanner(pipe)
			for scanner.Scan() {
				line := scanner.Text()
				log.Add(line)
				matches := pacmanRegex.FindStringSubmatch(line)
				if len(matches) > 2 && pInstance != nil {
					pInstance.Send(pkgUpdateMsg(fmt.Sprintf("%s %s", matches[2], matches[1])))
				}
			}
		}
		go scanPipe(stdout)
		go scanPipe(stderr)

		err := cmd.Wait()
		wg.Wait() // Ensure goroutines finish before reading log
		if err != nil {
			var errLines []string
			allLines := log.Lines()
			for _, line := range allLines {
				if strings.Contains(strings.ToLower(line), "error:") {
					errLines = append(errLines, strings.TrimSpace(line))
				}
			}
			errMsg := err.Error()
			if len(errLines) > 0 {
				errMsg = errLines[len(errLines)-1]
			} else if len(allLines) > 0 {
				errMsg = fmt.Sprintf("%v: %s", err, allLines[len(allLines)-1])
			}
			return taskCompletedMsg{err: fmt.Errorf("%s", errMsg)}
		}
		return taskCompletedMsg{err: nil}
	}
}

func main() {
	// T2 hardware pre-flight check (skip with SKIP_T2_CHECK=1)
	if os.Getenv("SKIP_T2_CHECK") != "1" {
		if err := checkT2Hardware(); err != nil {
			fmt.Fprintf(os.Stderr, "\n[WARN] %v\n\n", err)
		}
	}

	m := newModel()
	pInstance = tea.NewProgram(m)
	if _, err := pInstance.Run(); err != nil {
		fmt.Println("Error:", err)
		os.Exit(1)
	}
}
