package main

import (
	"testing"
)

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
