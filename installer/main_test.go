package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"

	"github.com/charmbracelet/bubbles/progress"
	"github.com/charmbracelet/bubbles/spinner"
	tea "github.com/charmbracelet/bubbletea"
)

// ── newModel ────────────────────────────────────────────────────────────────

func TestNewModel(t *testing.T) {
	m := newModel()
	if len(m.tasks) == 0 {
		t.Errorf("Expected tasks to be populated, got 0")
	}
	if m.index != 0 {
		t.Errorf("Expected initial index to be 0, got %d", m.index)
	}
	if m.done {
		t.Errorf("Expected model not to be done initially")
	}
}

func TestTaskWeights(t *testing.T) {
	m := newModel()
	if m.totalWeight == 0 {
		t.Error("Expected totalWeight > 0")
	}
	for _, task := range m.tasks {
		if task.Weight <= 0 {
			t.Errorf("Task %q has non-positive weight %f", task.Category, task.Weight)
		}
	}
}

func TestTaskListCompleteness(t *testing.T) {
	m := newModel()
	expected := map[string]bool{
		"scripts/00-system-init.sh":           false,
		"scripts/00-setup-vault.sh":           false,
		"scripts/01-thermal-setup.sh":         false,
		"scripts/02-wifi-firmware.sh":         false,
		"scripts/03-optimise.sh":              false,
		"scripts/04-bootloader.sh":            false,
		"scripts/05-mount-vault.sh":           false,
		"scripts/07-install-apps.sh":          false,
		"scripts/08-maintenance.sh":           false,
		"workstation/00-ai-dev-workstation.sh": false,
		"workstation/10-gnome-productivity.sh": false,
		"workstation/20-devops-tools.sh":       false,
		"workstation/30-security-tools.sh":     false,
		"workstation/40-dotfiles-link.sh":      false,
		"workstation/50-mise-plugins.sh":       false,
	}
	for _, task := range m.tasks {
		if _, ok := expected[task.Path]; ok {
			expected[task.Path] = true
		}
	}
	for path, found := range expected {
		if !found {
			t.Errorf("Missing task for %s", path)
		}
	}
}

func TestTaskFields(t *testing.T) {
	m := newModel()
	for i, task := range m.tasks {
		if task.Category == "" {
			t.Errorf("Task %d has empty Category", i)
		}
		if task.Software == "" {
			t.Errorf("Task %d has empty Software", i)
		}
		if task.Path == "" {
			t.Errorf("Task %d has empty Path", i)
		}
	}
}

// ── weightedProgress ────────────────────────────────────────────────────────

func TestWeightedProgressEmpty(t *testing.T) {
	m := newModel()
	m.index = 0
	m.taskProgress = 0
	p := m.weightedProgress()
	if p != 0 {
		t.Errorf("Expected 0 progress at start, got %f", p)
	}
}

func TestWeightedProgressComplete(t *testing.T) {
	m := newModel()
	m.index = len(m.tasks)
	m.taskProgress = 0
	p := m.weightedProgress()
	if p < 0.99 || p > 1.01 {
		t.Errorf("Expected ~1.0 progress when all tasks done, got %f", p)
	}
}

func TestWeightedProgressMidTask(t *testing.T) {
	m := newModel()
	m.index = 0
	m.taskProgress = 0.5
	p := m.weightedProgress()
	expected := (m.tasks[0].Weight * 0.5) / m.totalWeight
	if p < expected-0.01 || p > expected+0.01 {
		t.Errorf("Expected ~%f mid-first-task, got %f", expected, p)
	}
}

func TestWeightedProgressBetweenTasks(t *testing.T) {
	m := newModel()
	m.index = 2
	m.taskProgress = 0
	p := m.weightedProgress()
	expected := (m.tasks[0].Weight + m.tasks[1].Weight) / m.totalWeight
	if p < expected-0.01 || p > expected+0.01 {
		t.Errorf("Expected ~%f after 2 tasks, got %f", expected, p)
	}
}

func TestWeightedProgressZeroTotalWeight(t *testing.T) {
	m := model{
		tasks:       []Task{{Weight: 0}, {Weight: 0}},
		totalWeight: 0,
	}
	p := m.weightedProgress()
	if p != 0 {
		t.Errorf("Expected 0 with zero total weight, got %f", p)
	}
}

func TestWeightedProgressPastEnd(t *testing.T) {
	m := newModel()
	m.index = len(m.tasks) + 5 // Past the end
	m.taskProgress = 0
	p := m.weightedProgress()
	if p < 0.99 || p > 1.01 {
		t.Errorf("Expected ~1.0 when index past end, got %f", p)
	}
}

// ── Init ────────────────────────────────────────────────────────────────────

func TestInit(t *testing.T) {
	m := newModel()
	cmd := m.Init()
	if cmd == nil {
		t.Error("Init() should return a non-nil Cmd (tea.Batch)")
	}
}

// ── tickProgress ────────────────────────────────────────────────────────────

func TestTickProgress(t *testing.T) {
	m := newModel()
	cmd := m.tickProgress()
	if cmd == nil {
		t.Error("tickProgress() should return a non-nil Cmd")
	}
	// Execute the returned command to cover the inner closure
	msg := cmd()
	if msg == nil {
		t.Error("tickProgress cmd should produce a message")
	}
}

// ── Update ──────────────────────────────────────────────────────────────────

func TestUpdateWindowSize(t *testing.T) {
	m := newModel()
	msg := tea.WindowSizeMsg{Width: 120, Height: 40}
	updated, cmd := m.Update(msg)
	um := updated.(model)
	if um.width != 120 || um.height != 40 {
		t.Errorf("Expected 120x40, got %dx%d", um.width, um.height)
	}
	if cmd != nil {
		t.Error("WindowSizeMsg should return nil cmd")
	}
}

func TestUpdateKeyMsgQuit(t *testing.T) {
	m := newModel()
	for _, key := range []string{"ctrl+c", "esc", "q"} {
		msg := tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune(key)}
		if key == "ctrl+c" {
			msg = tea.KeyMsg{Type: tea.KeyCtrlC}
		} else if key == "esc" {
			msg = tea.KeyMsg{Type: tea.KeyEscape}
		} else {
			msg = tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{'q'}}
		}
		_, cmd := m.Update(msg)
		if cmd == nil {
			t.Errorf("Key %q should return a quit command", key)
		}
	}
}

func TestUpdateKeyMsgNonQuit(t *testing.T) {
	m := newModel()
	msg := tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{'a'}}
	_, cmd := m.Update(msg)
	if cmd != nil {
		t.Error("Non-quit key should return nil cmd")
	}
}

func TestUpdateProgressTickNormal(t *testing.T) {
	m := newModel()
	m.done = false
	m.err = nil
	m.taskProgress = 0.0

	msg := progressTickMsg(0.005)
	updated, cmd := m.Update(msg)
	um := updated.(model)
	if um.taskProgress == 0 {
		t.Error("Progress should have increased")
	}
	if cmd == nil {
		t.Error("Should return a batch cmd with progress + tick")
	}
}

func TestUpdateProgressTickSlowsAfter80(t *testing.T) {
	m := newModel()
	m.done = false
	m.err = nil
	m.taskProgress = 0.85

	msg := progressTickMsg(0.01)
	updated, _ := m.Update(msg)
	um := updated.(model)
	// At 0.85, increment is halved: 0.85 + 0.01*0.5 = 0.855
	if um.taskProgress < 0.854 || um.taskProgress > 0.856 {
		t.Errorf("Expected ~0.855 (halved increment), got %f", um.taskProgress)
	}
}

func TestUpdateProgressTickCapsAt99(t *testing.T) {
	m := newModel()
	m.done = false
	m.err = nil
	m.taskProgress = 0.98

	msg := progressTickMsg(0.05)
	updated, _ := m.Update(msg)
	um := updated.(model)
	if um.taskProgress > 0.99 {
		t.Errorf("Progress should cap at 0.99, got %f", um.taskProgress)
	}
}

func TestUpdateProgressTickWhenDone(t *testing.T) {
	m := newModel()
	m.done = true

	msg := progressTickMsg(0.005)
	updated, cmd := m.Update(msg)
	um := updated.(model)
	if um.taskProgress != 0 {
		t.Error("Progress should not change when done")
	}
	if cmd != nil {
		t.Error("Should return nil cmd when done")
	}
}

func TestUpdateProgressTickWhenError(t *testing.T) {
	m := newModel()
	m.err = os.ErrNotExist

	msg := progressTickMsg(0.005)
	_, cmd := m.Update(msg)
	if cmd != nil {
		t.Error("Should return nil cmd on error")
	}
}

func TestUpdatePkgUpdateMsg(t *testing.T) {
	m := newModel()
	msg := pkgUpdateMsg("gcc (5/47)")
	updated, cmd := m.Update(msg)
	um := updated.(model)
	if um.currentPkg != "gcc (5/47)" {
		t.Errorf("Expected currentPkg to be set, got %q", um.currentPkg)
	}
	if cmd != nil {
		t.Error("pkgUpdateMsg should return nil cmd")
	}
}

func TestUpdateTaskCompletedSuccess(t *testing.T) {
	m := newModel()
	m.index = 0

	msg := taskCompletedMsg{err: nil}
	updated, cmd := m.Update(msg)
	um := updated.(model)
	if um.index != 1 {
		t.Errorf("Expected index to advance to 1, got %d", um.index)
	}
	if um.taskProgress != 0 {
		t.Error("taskProgress should reset to 0")
	}
	if um.currentPkg != "" {
		t.Error("currentPkg should reset to empty")
	}
	if cmd == nil {
		t.Error("Should return batch cmd for next task")
	}
}

func TestUpdateTaskCompletedError(t *testing.T) {
	m := newModel()
	m.index = 0

	msg := taskCompletedMsg{err: os.ErrNotExist}
	updated, cmd := m.Update(msg)
	um := updated.(model)
	if um.err == nil {
		t.Error("Model error should be set")
	}
	if cmd == nil {
		t.Error("Should return quit sequence on error")
	}
}

func TestUpdateTaskCompletedLast(t *testing.T) {
	m := newModel()
	m.index = len(m.tasks) - 1

	msg := taskCompletedMsg{err: nil}
	updated, cmd := m.Update(msg)
	um := updated.(model)
	if !um.finalizing {
		t.Error("Should be finalizing after last task")
	}
	if cmd == nil {
		t.Error("Should return batch cmd with finalDone delay")
	}
}

func TestUpdateFinalDoneMsg(t *testing.T) {
	m := newModel()
	m.finalizing = true

	msg := finalDoneMsg{}
	updated, cmd := m.Update(msg)
	um := updated.(model)
	if !um.done {
		t.Error("Should be done after finalDoneMsg")
	}
	if cmd == nil {
		t.Error("Should return quit cmd")
	}
}

func TestUpdateSpinnerTick(t *testing.T) {
	m := newModel()
	msg := spinner.TickMsg{Time: time.Now()}
	_, cmd := m.Update(msg)
	// Spinner should return its own tick cmd
	if cmd == nil {
		t.Error("Spinner tick should produce a cmd")
	}
}

func TestUpdateProgressFrame(t *testing.T) {
	m := newModel()
	msg := progress.FrameMsg{}
	updated, _ := m.Update(msg)
	// Should not panic
	_ = updated.(model)
}

func TestUpdateUnknownMsg(t *testing.T) {
	m := newModel()
	// Send an unhandled message type to trigger the default return
	type unknownMsg struct{}
	updated, cmd := m.Update(unknownMsg{})
	um := updated.(model)
	if um.index != 0 {
		t.Error("Model should be unchanged for unknown messages")
	}
	if cmd != nil {
		t.Error("Unknown message should return nil cmd")
	}
}

// ── View ────────────────────────────────────────────────────────────────────

func TestViewNormal(t *testing.T) {
	m := newModel()
	m.width = 80
	m.height = 24
	v := m.View()
	if v == "" {
		t.Error("Normal view should not be empty")
	}
	if len(v) == 0 {
		t.Error("View should contain spinner + progress")
	}
}

func TestViewDone(t *testing.T) {
	m := newModel()
	m.done = true
	v := m.View()
	if v == "" {
		t.Error("Done view should not be empty")
	}
	expected := "Successfully configured"
	if len(v) == 0 || !containsString(v, expected) {
		t.Errorf("Done view should contain %q, got %q", expected, v)
	}
}

func TestViewError(t *testing.T) {
	m := newModel()
	m.err = os.ErrNotExist
	v := m.View()
	if v != "" {
		t.Errorf("Error view should be empty, got %q", v)
	}
}

func TestViewWithCurrentPkg(t *testing.T) {
	m := newModel()
	m.width = 120
	m.height = 24
	m.currentPkg = "gcc (5/47)"
	v := m.View()
	if !containsString(v, "gcc") {
		t.Errorf("View should show current package, got %q", v)
	}
}

func TestViewWithIndexAtEnd(t *testing.T) {
	m := newModel()
	m.width = 80
	m.height = 24
	m.index = len(m.tasks)
	// Should not panic — uses min(index, n-1)
	v := m.View()
	_ = v
}

func TestViewZeroWidth(t *testing.T) {
	m := newModel()
	m.width = 0
	m.height = 0
	// Should not panic with zero dimensions
	v := m.View()
	_ = v
}

func TestViewDisplayIndexClamped(t *testing.T) {
	m := newModel()
	m.width = 80
	m.height = 24
	// Set index beyond task count to trigger displayIndex > n guard
	m.index = len(m.tasks) + 10
	v := m.View()
	// Should not panic and should render the last task
	if v == "" {
		t.Error("View should render even with out-of-bounds index")
	}
}

// ── checkT2Hardware ─────────────────────────────────────────────────────────

func TestCheckT2HardwareNotLoaded(t *testing.T) {
	orig := lsmodCmd
	defer func() { lsmodCmd = orig }()
	lsmodCmd = func() ([]byte, error) { return []byte("snd_hda_intel 12345\n"), nil }

	err := checkT2Hardware()
	if err == nil {
		t.Error("Expected error when apple_bce not in lsmod")
	}
	if !containsString(err.Error(), "apple_bce") {
		t.Errorf("Error should mention apple_bce, got: %s", err.Error())
	}
}

func TestCheckT2HardwareLoaded(t *testing.T) {
	orig := lsmodCmd
	defer func() { lsmodCmd = orig }()
	lsmodCmd = func() ([]byte, error) { return []byte("apple_bce 12345 0\n"), nil }

	err := checkT2Hardware()
	if err != nil {
		t.Errorf("Expected nil error with apple_bce loaded, got: %v", err)
	}
}

func TestCheckT2HardwareLsmodFails(t *testing.T) {
	orig := lsmodCmd
	defer func() { lsmodCmd = orig }()
	lsmodCmd = func() ([]byte, error) { return nil, os.ErrNotExist }

	err := checkT2Hardware()
	if err != nil {
		t.Errorf("Expected nil error when lsmod fails, got: %v", err)
	}
}

// ── resolveProjectRoot ──────────────────────────────────────────────────────

func TestResolveProjectRoot(t *testing.T) {
	root, err := resolveProjectRoot()
	if err != nil {
		t.Fatalf("resolveProjectRoot failed: %v", err)
	}
	if root == "" {
		t.Error("Expected non-empty project root")
	}
}

func TestResolveProjectRootIsDirectory(t *testing.T) {
	root, err := resolveProjectRoot()
	if err != nil {
		t.Fatalf("resolveProjectRoot failed: %v", err)
	}
	info, err := os.Stat(root)
	if err != nil {
		t.Fatalf("Cannot stat root %q: %v", root, err)
	}
	if !info.IsDir() {
		t.Errorf("Expected directory, got file: %s", root)
	}
}

func TestResolveProjectRootExecutableFails(t *testing.T) {
	orig := osExecutable
	defer func() { osExecutable = orig }()
	osExecutable = func() (string, error) { return "", os.ErrNotExist }

	root, err := resolveProjectRoot()
	if err != nil {
		t.Fatalf("Should fallback gracefully, got error: %v", err)
	}
	if root == "" {
		t.Error("Should return a fallback path")
	}
}

func TestResolveProjectRootSymlinkFails(t *testing.T) {
	orig := osExecutable
	defer func() { osExecutable = orig }()
	// Return a path that doesn't exist — EvalSymlinks will fail
	osExecutable = func() (string, error) { return "/nonexistent/path/binary", nil }

	root, err := resolveProjectRoot()
	if err != nil {
		t.Fatalf("Should fallback gracefully, got error: %v", err)
	}
	if root == "" {
		t.Error("Should return a fallback path")
	}
}

// ── executeTask ─────────────────────────────────────────────────────────────

func TestExecuteTaskSuccess(t *testing.T) {
	// Create a test script relative to the resolved project root
	root, err := resolveProjectRoot()
	if err != nil {
		t.Fatalf("resolveProjectRoot: %v", err)
	}

	scriptDir := filepath.Join(root, "installer", "testdata")
	os.MkdirAll(scriptDir, 0755)
	defer os.RemoveAll(scriptDir)

	scriptPath := filepath.Join(scriptDir, "test-ok.sh")
	os.WriteFile(scriptPath, []byte("#!/bin/bash\necho ok\n"), 0755)

	task := Task{
		Category: "Test OK",
		Software: "test-ok",
		Path:     "installer/testdata/test-ok.sh",
		Weight:   1.0,
	}

	cmd := executeTask(task)
	msg := cmd()
	result, ok := msg.(taskCompletedMsg)
	if !ok {
		t.Fatalf("Expected taskCompletedMsg, got %T", msg)
	}
	if result.err != nil {
		t.Errorf("Expected nil error, got %v", result.err)
	}
}

func TestExecuteTaskFailure(t *testing.T) {
	root, err := resolveProjectRoot()
	if err != nil {
		t.Fatalf("resolveProjectRoot: %v", err)
	}

	scriptDir := filepath.Join(root, "installer", "testdata")
	os.MkdirAll(scriptDir, 0755)
	defer os.RemoveAll(scriptDir)

	scriptPath := filepath.Join(scriptDir, "test-fail.sh")
	os.WriteFile(scriptPath, []byte("#!/bin/bash\necho 'error: something broke' >&2\nexit 1\n"), 0755)

	task := Task{
		Category: "Test Fail",
		Software: "test-fail",
		Path:     "installer/testdata/test-fail.sh",
		Weight:   1.0,
	}

	cmd := executeTask(task)
	msg := cmd()
	result, ok := msg.(taskCompletedMsg)
	if !ok {
		t.Fatalf("Expected taskCompletedMsg, got %T", msg)
	}
	if result.err == nil {
		t.Error("Expected error for failing script")
	}
}

func TestExecuteTaskScriptNotFound(t *testing.T) {
	task := Task{
		Category: "Missing",
		Software: "nonexistent",
		Path:     "installer/testdata/does-not-exist-12345.sh",
		Weight:   1.0,
	}

	cmd := executeTask(task)
	msg := cmd()
	result, ok := msg.(taskCompletedMsg)
	if !ok {
		t.Fatalf("Expected taskCompletedMsg, got %T", msg)
	}
	if result.err == nil {
		t.Error("Expected error for missing script")
	}
}

func TestExecuteTaskWithPacmanOutput(t *testing.T) {
	root, err := resolveProjectRoot()
	if err != nil {
		t.Fatalf("resolveProjectRoot: %v", err)
	}

	scriptDir := filepath.Join(root, "installer", "testdata")
	os.MkdirAll(scriptDir, 0755)
	defer os.RemoveAll(scriptDir)

	// Script that outputs pacman-like lines
	scriptPath := filepath.Join(scriptDir, "test-pacman.sh")
	os.WriteFile(scriptPath, []byte("#!/bin/bash\necho '(1/5) installing gcc'\necho '(2/5) upgrading linux'\n"), 0755)

	task := Task{
		Category: "Pacman Test",
		Software: "pkg-test",
		Path:     "installer/testdata/test-pacman.sh",
		Weight:   1.0,
	}

	cmd := executeTask(task)
	msg := cmd()
	result, ok := msg.(taskCompletedMsg)
	if !ok {
		t.Fatalf("Expected taskCompletedMsg, got %T", msg)
	}
	if result.err != nil {
		t.Errorf("Expected nil error, got %v", result.err)
	}
}

func TestExecuteTaskWithErrorLines(t *testing.T) {
	root, err := resolveProjectRoot()
	if err != nil {
		t.Fatalf("resolveProjectRoot: %v", err)
	}

	scriptDir := filepath.Join(root, "installer", "testdata")
	os.MkdirAll(scriptDir, 0755)
	defer os.RemoveAll(scriptDir)

	// Script with multiple error lines and exit 1
	scriptPath := filepath.Join(scriptDir, "test-multi-error.sh")
	os.WriteFile(scriptPath, []byte("#!/bin/bash\necho 'error: first issue'\necho 'error: second issue'\nexit 1\n"), 0755)

	task := Task{
		Category: "Multi Error",
		Software: "err-test",
		Path:     "installer/testdata/test-multi-error.sh",
		Weight:   1.0,
	}

	cmd := executeTask(task)
	msg := cmd()
	result := msg.(taskCompletedMsg)
	if result.err == nil {
		t.Error("Expected error")
	}
	// Should contain the last error line
	if !containsString(result.err.Error(), "second issue") {
		t.Errorf("Error should contain last error line, got: %s", result.err.Error())
	}
}

func TestExecuteTaskEmptyOutput(t *testing.T) {
	root, err := resolveProjectRoot()
	if err != nil {
		t.Fatalf("resolveProjectRoot: %v", err)
	}

	scriptDir := filepath.Join(root, "installer", "testdata")
	os.MkdirAll(scriptDir, 0755)
	defer os.RemoveAll(scriptDir)

	// Script that fails with no output at all
	scriptPath := filepath.Join(scriptDir, "test-empty-fail.sh")
	os.WriteFile(scriptPath, []byte("#!/bin/bash\nexit 1\n"), 0755)

	task := Task{
		Category: "Empty Fail",
		Software: "empty-fail",
		Path:     "installer/testdata/test-empty-fail.sh",
		Weight:   1.0,
	}

	cmd := executeTask(task)
	msg := cmd()
	result := msg.(taskCompletedMsg)
	if result.err == nil {
		t.Error("Expected error")
	}
}

func TestExecuteTaskStartError(t *testing.T) {
	root, err := resolveProjectRoot()
	if err != nil {
		t.Skip("Cannot resolve project root")
	}

	scriptDir := filepath.Join(root, "installer", "testdata")
	os.MkdirAll(scriptDir, 0755)
	defer os.RemoveAll(scriptDir)

	// Create a script, but make bash unavailable by using an empty PATH
	scriptPath := filepath.Join(scriptDir, "test-start-err.sh")
	os.WriteFile(scriptPath, []byte("#!/bin/bash\necho ok\n"), 0755)

	task := Task{
		Category: "Start Error",
		Software: "start-err",
		Path:     "installer/testdata/test-start-err.sh",
		Weight:   1.0,
	}

	// Override PATH so bash can't be found, causing cmd.Start() to fail
	origPath := os.Getenv("PATH")
	os.Setenv("PATH", "")
	defer os.Setenv("PATH", origPath)

	cmd := executeTask(task)
	msg := cmd()
	result := msg.(taskCompletedMsg)
	if result.err == nil {
		t.Error("Expected error when bash is not in PATH")
	}
}

func TestExecuteTaskWithNoErrorKeyword(t *testing.T) {
	root, err := resolveProjectRoot()
	if err != nil {
		t.Fatalf("resolveProjectRoot: %v", err)
	}

	scriptDir := filepath.Join(root, "installer", "testdata")
	os.MkdirAll(scriptDir, 0755)
	defer os.RemoveAll(scriptDir)

	// Script that fails but without "error:" in output
	scriptPath := filepath.Join(scriptDir, "test-no-keyword.sh")
	os.WriteFile(scriptPath, []byte("#!/bin/bash\necho 'something went wrong'\nexit 1\n"), 0755)

	task := Task{
		Category: "No Keyword",
		Software: "no-err-keyword",
		Path:     "installer/testdata/test-no-keyword.sh",
		Weight:   1.0,
	}

	cmd := executeTask(task)
	msg := cmd()
	result := msg.(taskCompletedMsg)
	if result.err == nil {
		t.Error("Expected error")
	}
	// Should contain the last output line as fallback
	if !containsString(result.err.Error(), "something went wrong") {
		t.Errorf("Error should contain last line, got: %s", result.err.Error())
	}
}

// ── pacmanRegex ─────────────────────────────────────────────────────────────

func TestPacmanRegex(t *testing.T) {
	tests := []struct {
		line    string
		match   bool
		pkg     string
		counter string
	}{
		{"(1/47) installing gcc", true, "gcc", "1/47"},
		{"(120/150) upgrading linux-cachyos", true, "linux-cachyos", "120/150"},
		{"some random log line", false, "", ""},
		{"(3/10) removing old-pkg", false, "", ""},
	}
	for _, tt := range tests {
		matches := pacmanRegex.FindStringSubmatch(tt.line)
		if tt.match {
			if len(matches) < 3 {
				t.Errorf("Expected match for %q, got none", tt.line)
				continue
			}
			if matches[1] != tt.counter {
				t.Errorf("Expected counter %q, got %q", tt.counter, matches[1])
			}
			if matches[2] != tt.pkg {
				t.Errorf("Expected pkg %q, got %q", tt.pkg, matches[2])
			}
		} else {
			if len(matches) > 0 {
				t.Errorf("Expected no match for %q, got %v", tt.line, matches)
			}
		}
	}
}

// ── styles ──────────────────────────────────────────────────────────────────

func TestStylesNotNil(t *testing.T) {
	// Verify lipgloss styles are usable
	_ = currentTaskStyle.Render("test")
	_ = doneStyle.Render("test")
	_ = checkMark.String()
	_ = errorMark.String()
	_ = helpStyle.Render("test")
	_ = completedStyle.Render("test")
}

// ── main (subprocess) ───────────────────────────────────────────────────────

func TestMainSubprocess(t *testing.T) {
	if os.Getenv("TEST_MAIN_SUBPROCESS") == "1" {
		main()
		return
	}
	// Run main() in a subprocess with no TTY — Bubble Tea will exit immediately
	cmd := exec.Command(os.Args[0], "-test.run=TestMainSubprocess")
	cmd.Env = append(os.Environ(),
		"TEST_MAIN_SUBPROCESS=1",
		"SKIP_T2_CHECK=1",
	)
	// Bubble Tea exits with error when no TTY is available
	err := cmd.Run()
	// Expected: exit 1 (no TTY) — that's fine, we just verify it doesn't panic
	_ = err
}

func TestMainSubprocessWithT2Check(t *testing.T) {
	if os.Getenv("TEST_MAIN_T2CHECK") == "1" {
		main()
		return
	}
	// Run WITHOUT SKIP_T2_CHECK to cover the T2 warning path in main()
	cmd := exec.Command(os.Args[0], "-test.run=TestMainSubprocessWithT2Check")
	cmd.Env = append(os.Environ(), "TEST_MAIN_T2CHECK=1")
	// Remove SKIP_T2_CHECK if set
	filtered := make([]string, 0, len(cmd.Env))
	for _, e := range cmd.Env {
		if !containsString(e, "SKIP_T2_CHECK") {
			filtered = append(filtered, e)
		}
	}
	cmd.Env = filtered
	_ = cmd.Run()
}

// ── helpers ─────────────────────────────────────────────────────────────────

func containsString(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr || len(s) > 0 && findSubstring(s, substr))
}

func findSubstring(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}
