package main

import (
	"testing"
)

func TestMax(t *testing.T) {
	// A basic test to ensure our math helper works
	if max(5, 3) != 5 {
		t.Errorf("Expected 5, got %d", max(5, 3))
	}
	if max(2, 8) != 8 {
		t.Errorf("Expected 8, got %d", max(2, 8))
	}
	if max(-1, 0) != 0 {
		t.Errorf("Expected 0, got %d", max(-1, 0))
	}
}

func TestNewModel(t *testing.T) {
	// Ensure the model is correctly instantiated
	m := newModel()
	if len(m.tasks) == 0 {
		t.Errorf("Expected tasks to be populated, got 0")
	}
	if m.index != 0 {
		t.Errorf("Expected initial index to be 0, got %d", m.index)
	}
	if m.done != false {
		t.Errorf("Expected model not to be done initially")
	}
}
