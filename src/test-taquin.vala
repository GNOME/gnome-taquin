/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-

   This file is part of GNOME Taquin.

   Copyright (C) 2019 – Arnaud Bonatti <arnaud.bonatti@gmail.com>

   GNOME Taquin is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   GNOME Taquin is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with GNOME Taquin.  If not, see <https://www.gnu.org/licenses/>.
*/

private class TestTaquin : Object
{
    private static int main (string [] args)
    {
        Test.init (ref args);
        Test.add_func ("/Taquin/test tests",
                                test_tests);
        Test.add_func ("/Taquin/test a Fifteen 2 by 2 validity",
                                test_fifteen_validity);
        return Test.run ();
    }

    private static void test_tests ()
    {
        assert_true (1 + 1 == 2);
    }

    /*\
    * * test the Fifteen two by two
    \*/

    /*
                VALID                              INVALID
    ┌───┬───┐ ┌───┬───┐ ┌───┬───┐       ┌───┬───┐ ┌───┬───┐ ┌───┬───┐
    │[0]│ 2 │ │ 3 │ 2 │ │ 3 │ 2 │       │   │ 2 │ │ 4 │ 2 │ │ 4 │ 2 │
    ├───┼───┤ ├───┼───┤ ├───┼───┤       ├───┼───┤ ├───┼───┤ ├───┼───┤
    │ 3 │ 4 │ │   │ 4 │ │ 4 │   │       │ 4 │ 3 │ │   │ 3 │ │ 3 │   │
    └───┴───┘ └───┴───┘ └───┴───┘       └───┴───┘ └───┴───┘ └───┴───┘
    ┌───┬───┐ ┌───┬───┐ ┌───┬───┐       ┌───┬───┐ ┌───┬───┐ ┌───┬───┐
    │ 3 │   │ │   │ 3 │ │ 4 │ 3 │       │ 4 │   │ │   │ 4 │ │ 3 │ 4 │
    ├───┼───┤ ├───┼───┤ ├───┼───┤       ├───┼───┤ ├───┼───┤ ├───┼───┤
    │ 4 │ 2 │ │ 4 │ 2 │ │   │ 2 │       │ 3 │ 2 │ │ 3 │ 2 │ │   │ 2 │
    └───┴───┘ └───┴───┘ └───┴───┘       └───┴───┘ └───┴───┘ └───┴───┘
    ┌───┬───┐ ┌───┬───┐ ┌───┬───┐       ┌───┬───┐ ┌───┬───┐ ┌───┬───┐
    │ 4 │ 3 │ │ 4 │   │ │   │ 4 │       │ 3 │ 4 │ │ 3 │   │ │   │ 3 │
    ├───┼───┤ ├───┼───┤ ├───┼───┤       ├───┼───┤ ├───┼───┤ ├───┼───┤
    │ 2 │   │ │ 2 │ 3 │ │ 2 │ 3 │       │ 2 │   │ │ 2 │ 4 │ │ 2 │ 4 │
    └───┴───┘ └───┴───┘ └───┴───┘       └───┴───┘ └───┴───┘ └───┴───┘
    ┌───┬───┐ ┌───┬───┐ ┌───┬───┐       ┌───┬───┐ ┌───┬───┐ ┌───┬───┐
    │ 2 │ 4 │ │ 2 │ 4 │ │ 2 │   │       │ 2 │ 3 │ │ 2 │ 3 │ │ 2 │   │
    ├───┼───┤ ├───┼───┤ ├───┼───┤       ├───┼───┤ ├───┼───┤ ├───┼───┤
    │   │ 3 │ │ 3 │   │ │ 3 │ 4 │       │   │ 4 │ │ 4 │   │ │ 4 │ 3 │
    └───┴───┘ └───┴───┘ └───┴───┘       └───┴───┘ └───┴───┘ └───┴───┘
    */

    /* This test is a bit abstract: it tests for all the valid places,
       but Taquin shows the empty tile at the top-left corner, always. */
    private static void test_fifteen_validity ()
    {
        for (uint i = 0; i < 100; i++) // should be good enough
        {
            Game game = new Game (GameType.FIFTEEN, 2); // TODO use GameType.SIXTEEN instead?
            print (@"\ntest: $game");

            if (compare_value (ref game, 1, 0, 2))
            {
                assert_true (compare_value (ref game, 0, 0, 3) || compare_value (ref game, 0, 1, 3));
                assert_true (compare_value (ref game, 1, 1, 4) || compare_value (ref game, 0, 1, 4));
            }
            else if (compare_value (ref game, 1, 1, 2))
            {
                assert_true (compare_value (ref game, 1, 0, 3) || compare_value (ref game, 0, 0, 3));
                assert_true (compare_value (ref game, 0, 1, 4) || compare_value (ref game, 0, 0, 4));
            }
            else if (compare_value (ref game, 0, 1, 2))
            {
                assert_true (compare_value (ref game, 1, 1, 3) || compare_value (ref game, 1, 0, 3));
                assert_true (compare_value (ref game, 0, 0, 4) || compare_value (ref game, 1, 0, 4));
            }
            else if (compare_value (ref game, 0, 0, 2))
            {
                assert_true (compare_value (ref game, 0, 1, 3) || compare_value (ref game, 1, 1, 3));
                assert_true (compare_value (ref game, 1, 0, 4) || compare_value (ref game, 1, 1, 4));
            }
            else
                Test.fail ();
        }
    }
    private static bool compare_value (ref Game game, int8 x, int8 y, int8 k)
        requires (x >= 0)
        requires (x < game.size)
        requires (y >= 0)
        requires (y < game.size)
    {
        return game.get_tile_value (x, y) + 1 == k;
    }
}
