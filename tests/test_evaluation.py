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
        assert evaluate(42, 42, 1, 100) == Evaluation.CORRECT
        assert evaluate(0, 0, -10, 10) == Evaluation.CORRECT
        assert evaluate(-10, -10, -20, 0) == Evaluation.CORRECT
        assert evaluate(1000, 1000, 0, 2000) == Evaluation.CORRECT

    def test_evaluate_high_guess(self):
        """Test that evaluate returns HIGH when guess is greater than value."""
        assert evaluate(42, 43, 1, 100) == Evaluation.HIGH
        assert evaluate(42, 100, 1, 100) == Evaluation.HIGH
        assert evaluate(0, 1, -10, 10) == Evaluation.HIGH
        assert evaluate(-10, 0, -20, 10) == Evaluation.HIGH

    def test_evaluate_low_guess(self):
        """Test that evaluate returns LOW when guess is less than value."""
        assert evaluate(42, 41, 1, 100) == Evaluation.LOW
        assert evaluate(42, 1, 1, 100) == Evaluation.LOW
        assert evaluate(0, -1, -10, 10) == Evaluation.LOW
        assert evaluate(10, -10, -20, 20) == Evaluation.LOW

    def test_evaluate_boundary_cases(self):
        """Test evaluate with boundary values."""
        # Just above and below
        assert evaluate(50, 51, 1, 100) == Evaluation.HIGH
        assert evaluate(50, 49, 1, 100) == Evaluation.LOW

        # Large differences
        assert evaluate(0, 1000000, 0, 2000000) == Evaluation.HIGH
        assert evaluate(1000000, 0, 0, 2000000) == Evaluation.LOW

    def test_evaluate_negative_values(self):
        """Test evaluate with negative values."""
        assert evaluate(-50, -49, -100, 0) == Evaluation.HIGH
        assert evaluate(-50, -51, -100, 0) == Evaluation.LOW
        assert evaluate(-50, -50, -100, 0) == Evaluation.CORRECT

    def test_evaluate_value_at_bounds(self):
        """Test that evaluate accepts values at the boundaries."""
        # Value at minimum bound
        assert evaluate(1, 1, 1, 100) == Evaluation.CORRECT
        assert evaluate(1, 2, 1, 100) == Evaluation.HIGH

        # Value at maximum bound
        assert evaluate(100, 100, 1, 100) == Evaluation.CORRECT
        assert evaluate(100, 99, 1, 100) == Evaluation.LOW

    def test_evaluate_value_below_minimum_raises_error(self):
        """Test that evaluate raises ValueError when value is below minimum."""
        with pytest.raises(ValueError, match=r"Value 0 is outside the allowed range \[1, 100\]"):
            evaluate(0, 50, 1, 100)

        with pytest.raises(ValueError, match=r"Value -1 is outside the allowed range \[1, 100\]"):
            evaluate(-1, 50, 1, 100)

    def test_evaluate_value_above_maximum_raises_error(self):
        """Test that evaluate raises ValueError when value is above maximum."""
        with pytest.raises(ValueError, match=r"Value 101 is outside the allowed range \[1, 100\]"):
            evaluate(101, 50, 1, 100)

        with pytest.raises(ValueError, match=r"Value 200 is outside the allowed range \[1, 100\]"):
            evaluate(200, 50, 1, 100)
