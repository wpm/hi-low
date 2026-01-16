"""Command line interface for the Hi-Low guessing game."""

import argparse
import random

from hi_low.game_loop import game_loop


def main() -> None:
    """Run the Hi-Low guessing game from the command line."""
    parser = argparse.ArgumentParser(
        description="Hi-Low number guessing game",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )

    parser.add_argument(
        "--min-value",
        type=int,
        default=1,
        help="Minimum value for the random number range",
    )

    parser.add_argument(
        "--max-value",
        type=int,
        default=100,
        help="Maximum value for the random number range",
    )

    parser.add_argument(
        "--max-guesses",
        type=int,
        default=10,
        help="Maximum number of guesses allowed",
    )

    parser.add_argument(
        "--seed",
        type=int,
        default=None,
        help="Random seed for reproducible games (optional)",
    )

    args = parser.parse_args()

    # Print all input parameters
    print(f"min_value: {args.min_value}")
    print(f"max_value: {args.max_value}")
    print(f"max_guesses: {args.max_guesses}")
    print(f"seed: {args.seed}")

    # Set random seed if provided
    if args.seed is not None:
        random.seed(args.seed)

    # Generate random value to guess
    value = random.randint(args.min_value, args.max_value)

    # Run the game loop
    won = game_loop(value, args.max_guesses)

    # Print the result
    if won:
        print("You won")
    else:
        print("You lost")


if __name__ == "__main__":
    main()
