"""Evaluation function for comparing a guess against a target value."""

from enum import Enum


class Evaluation(Enum):
    """Result of evaluating a guess against a target value."""

    CORRECT = "correct"
    HIGH = "high"
    LOW = "low"


def evaluate(value: int, guess: int) -> Evaluation:
    """
    Evaluate a guess against a target value.

    Args:
        value: The target value to guess.
        guess: The guessed value.

    Returns:
        Evaluation.CORRECT if the guess matches the value.
        Evaluation.HIGH if the guess is greater than the value.
        Evaluation.LOW if the guess is less than the value.
    """
    if guess == value:
        return Evaluation.CORRECT
    elif guess > value:
        return Evaluation.HIGH
    else:
        return Evaluation.LOW
