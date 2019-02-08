/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright (C) 2019 Arnaud Bonatti <arnaud.bonatti@gmail.com>
 *
 * This file is part of Taquin.
 *
 * Taquin is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Taquin is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.

 * You should have received a copy of the GNU General Public License
 * along with Taquin. If not, see <http://www.gnu.org/licenses/>.
 */

private class TestTaquin : Object
{
    private static int main (string [] args)
    {
        Test.init (ref args);
        Test.add_func ("/Taquin/test tests", test_tests);
        return Test.run ();
    }

    private static void test_tests ()
    {
        assert (1 + 1 == 2);
    }

    /*\
    * * tests
    \*/
}
