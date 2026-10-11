import unittest

from counter import increment


class CounterTest(unittest.TestCase):
    def test_increment(self):
        self.assertEqual(increment(2), 3)
        self.assertEqual(increment(-1), 0)


if __name__ == "__main__":
    unittest.main()
