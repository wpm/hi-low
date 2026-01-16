"""Tests for the evaluation module."""

import pytest
from hi_low.evaluation import Evaluation, evaluate


class TestEvaluation:
    """Tests for the Evaluation enum."""

    def test_evaluation_enum_values(self):
        """Test that the Evaluation enum has the expected values."""
        assert Evaluation.CORRECT.value == "correct"
        assert Evaluation.HIGH.value == "high"
        assert Evaluation.LOW.value == "low"

    def test_evaluation_enum_count(self):
        """Test that the Evaluation enum has exactly three members."""
        assert len(Evaluation) == 3


class TestEvaluate:
    """Tests for the evaluate function."""

    def test_evaluate_correct_guess(self):
        """Test that evaluate returns CORRECT when guess equals value."""
        assert evaluate(42, 42) == Evaluation.CORRECT
        assert evaluate(0, 0) == Evaluation.CORRECT
        assert evaluate(-10, -10) == Evaluation.CORRECT
        assert evaluate(1000, 1000) == Evaluation.CORRECT

    def test_evaluate_high_guess(self):
        """Test that evaluate returns HIGH when guess is greater than value."""
        assert evaluate(42, 43) == Evaluation.HIGH
        assert evaluate(42, 100) == Evaluation.HIGH
        assert evaluate(0, 1) == Evaluation.HIGH
        assert evaluate(-10, 0) == Evaluation.HIGH

    def test_evaluate_low_guess(self):
        """Test that evaluate returns LOW when guess is less than value."""
        assert evaluate(42, 41) == Evaluation.LOW
        assert evaluate(42, 1) == Evaluation.LOW
        assert evaluate(0, -1) == Evaluation.LOW
        assert evaluate(10, -10) == Evaluation.LOW

    def test_evaluate_boundary_cases(self):
        """Test evaluate with boundary values."""
        # Just above and below
        assert evaluate(50, 51) == Evaluation.HIGH
        assert evaluate(50, 49) == Evaluation.LOW

        # Large differences
        assert evaluate(0, 1000000) == Evaluation.HIGH
        assert evaluate(1000000, 0) == Evaluation.LOW

    def test_evaluate_negative_values(self):
        """Test evaluate with negative values."""
        assert evaluate(-50, -49) == Evaluation.HIGH
        assert evaluate(-50, -51) == Evaluation.LOW
        assert evaluate(-50, -50) == Evaluation.CORRECT
