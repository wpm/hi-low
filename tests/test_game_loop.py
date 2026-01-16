"""Tests for the game loop module."""

from unittest.mock import patch

import pytest

from hi_low.game_loop import game_loop


class TestGameLoop:
    """Tests for the game_loop function."""

    def test_correct_guess_first_try(self, capsys):
        """Test that the player wins on the first guess."""
        with patch("builtins.input", return_value="42"):
            result = game_loop(42, 5)
            captured = capsys.readouterr()

            assert result is True
            assert captured.out == "correct\n"

    def test_correct_guess_last_try(self, capsys):
        """Test that the player wins on the last allowed guess."""
        with patch("builtins.input", side_effect=["10", "20", "30", "40", "50"]):
            result = game_loop(50, 5)
            captured = capsys.readouterr()

            assert result is True
            assert captured.out == "low\nlow\nlow\nlow\ncorrect\n"

    def test_correct_guess_middle_try(self, capsys):
        """Test that the player wins on a middle guess."""
        with patch("builtins.input", side_effect=["10", "20", "42"]):
            result = game_loop(42, 5)
            captured = capsys.readouterr()

            assert result is True
            assert captured.out == "low\nlow\ncorrect\n"

    def test_max_guesses_reached_without_win(self, capsys):
        """Test that the player loses after reaching max guesses."""
        with patch("builtins.input", side_effect=["10", "20", "30"]):
            result = game_loop(42, 3)
            captured = capsys.readouterr()

            assert result is False
            assert captured.out == "low\nlow\nlow\n"

    def test_high_guesses(self, capsys):
        """Test that high guesses are evaluated correctly."""
        with patch("builtins.input", side_effect=["100", "90", "80", "42"]):
            result = game_loop(42, 5)
            captured = capsys.readouterr()

            assert result is True
            assert captured.out == "high\nhigh\nhigh\ncorrect\n"

    def test_mixed_guesses(self, capsys):
        """Test a mix of high and low guesses."""
        with patch("builtins.input", side_effect=["10", "100", "50", "40", "45", "42"]):
            result = game_loop(42, 6)
            captured = capsys.readouterr()

            assert result is True
            assert captured.out == "low\nhigh\nhigh\nlow\nhigh\ncorrect\n"

    def test_exactly_one_guess_allowed(self, capsys):
        """Test game with only one guess allowed."""
        with patch("builtins.input", return_value="42"):
            result = game_loop(42, 1)
            captured = capsys.readouterr()

            assert result is True
            assert captured.out == "correct\n"

        with patch("builtins.input", return_value="10"):
            result = game_loop(42, 1)
            captured = capsys.readouterr()

            assert result is False
            assert captured.out == "low\n"

    def test_no_extra_output(self, capsys):
        """Test that no extra output is produced beyond evaluation results."""
        with patch("builtins.input", side_effect=["10", "42"]):
            game_loop(42, 3)
            captured = capsys.readouterr()

            # Verify output contains only evaluation strings and newlines
            lines = captured.out.strip().split("\n")
            assert len(lines) == 2
            assert lines[0] == "low"
            assert lines[1] == "correct"

    def test_negative_values(self, capsys):
        """Test game loop with negative target values."""
        with patch("builtins.input", side_effect=["-100", "-50", "-42"]):
            result = game_loop(-42, 5)
            captured = capsys.readouterr()

            assert result is True
            assert captured.out == "low\nlow\ncorrect\n"

    def test_large_values(self, capsys):
        """Test game loop with large values."""
        with patch("builtins.input", side_effect=["1000000", "500000", "100000"]):
            result = game_loop(100000, 3)
            captured = capsys.readouterr()

            assert result is True
            assert captured.out == "high\nhigh\ncorrect\n"
