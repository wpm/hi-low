"""Game loop for the Hi-Low number guessing game."""

from hi_low.evaluation import Evaluation, evaluate


def game_loop(value: int, max_guesses: int) -> bool:
    """
    Run the main game loop for the Hi-Low guessing game.

    Takes user input via the input() function and evaluates each guess.
    Prints "correct", "high", or "low" for each guess based on the evaluation.
    The loop exits when the player guesses correctly or reaches max_guesses.

    Args:
        value: The target value that the player needs to guess.
        max_guesses: The maximum number of guesses allowed.

    Returns:
        True if the player guessed correctly within max_guesses, False otherwise.
    """
    for _ in range(max_guesses):
        guess = int(input())
        result = evaluate(value, guess)
        print(result.value)

        if result == Evaluation.CORRECT:
            return True

    return False
