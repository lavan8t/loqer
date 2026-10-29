#!/usr/bin/env python3
"""LOQer test runner.

Discovers and executes all unit tests under the tests/ directory.
Exits with code 0 on success, 1 on failure.
"""

import os
import sys
import unittest


def main() -> None:
    # Ensure project root and tests directory are in sys.path
    tests_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(tests_dir)
    if project_root not in sys.path:
        sys.path.insert(0, project_root)
    if tests_dir not in sys.path:
        sys.path.insert(0, tests_dir)

    loader = unittest.defaultTestLoader
    suite = loader.discover(start_dir=tests_dir, pattern="test_*.py")

    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)

    sys.exit(0 if result.wasSuccessful() else 1)


if __name__ == "__main__":
    main()
