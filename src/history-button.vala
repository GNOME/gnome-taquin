/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-

   This file is part of a GNOME game

   Copyright (C) 2019 – Arnaud Bonatti <arnaud.bonatti@gmail.com>

   This application is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This application is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License along
   with this application.  If not, see <https://www.gnu.org/licenses/>.
*/

using Gtk;

[GtkTemplate (ui = "/org/gnome/Taquin/ui/history-button.ui")]
private class HistoryButton : MenuButton
{
    construct
    {
        update_state (/* label */ "0", /* sensitive */ false);
        generate_moves_menu ();
    }

    /*\
    * * utilities
    \*/

    private void update_state (string label, bool sensitive)
    {
        set_label (label);
        set_sensitive (sensitive);
    }

    private static string get_moves_count_string (ref uint moves_count)
    {
        string moves_count_string;
        if (moves_count != uint.MAX)
            moves_count_string = moves_count.to_string ();
        else
            moves_count_string = "∞";
        return moves_count_string;
    }

    /*\
    * * menu generation
    \*/

    private void generate_moves_menu ()
    {
        GLib.Menu menu = new GLib.Menu ();
        generate_undo_actions_section (ref menu);
        if (best_score != 0)
            generate_best_score_section (ref best_score, ref menu);
        menu.freeze ();
        set_menu_model (menu);
    }

    private static inline void generate_undo_actions_section (ref GLib.Menu menu)
    {
        GLib.Menu section = new GLib.Menu ();
        /* Translators: during a game, entry in the menu of the history menubutton (with a mnemonic that appears pressing Alt) */
        section.append (_("_Undo"), "ui.undo");

        /* Translators: during a game, entry in the menu of the history menubutton (with a mnemonic that appears pressing Alt) */
        section.append (_("_Restart"), "ui.restart");

        section.freeze ();
        menu.append_section (null, section);
    }

    private static inline void generate_best_score_section (ref uint best_score, ref GLib.Menu menu)
    {
        GLib.Menu section = new GLib.Menu ();

        /* Translators: during a game that has already been finished (and possibly restarted), entry in the menu of the moves button */
        section.append (_("Best score: %s").printf (get_moves_count_string (ref best_score)), null);

        section.freeze ();
        menu.append_section (null, section);
    }

    /*\
    * * moves menu
    \*/

    private uint best_score = 0;
    internal void save_best_score (out string best_score_string)
    {
        get_best_score_string (ref best_score, ref last_moves_count, out best_score_string);

        if ((best_score == 0) || (last_moves_count < best_score))
            best_score = last_moves_count;
        generate_moves_menu ();
    }

    private static inline void get_best_score_string (ref uint best_score, ref uint last_moves_count, out string best_score_string)
    {
        if (best_score == 0)
        {
            best_score_string = usual_best_score_string;
            return;
        }

        if (last_moves_count < best_score)
        {
            /* Translators: in-window notification; on both games, if the user solved the puzzle more than one time */
            best_score_string =    _("Bravo! You improved your best score!");
            if (best_score_string != "Bravo! You improved your best score!")
                return;
        }
        else if (last_moves_count == best_score)
        {
            /* Translators: in-window notification; on both games, if the user solved the puzzle more than one time */
            best_score_string =    _("Bravo! You equalized your best score.");
            if (best_score_string != "Bravo! You equalized your best score.")
                return;
        }
        else
        {
            /* Translators: in-window notification; on both games, if the user solved the puzzle more than one time */
            best_score_string =    _("Bravo! You finished the game again.");
            if (best_score_string != "Bravo! You finished the game again.")
                return;
        }

        if (usual_best_score_string_untranslated != usual_best_score_string)
            best_score_string = usual_best_score_string;
    }
    /* Translators: in-window notification; on both games, if the user solves the puzzle the first time */
    private const string usual_best_score_string              = _("Bravo! You finished the game!");
    private const string usual_best_score_string_untranslated =   "Bravo! You finished the game!" ;

    /*\
    * * some internal calls
    \*/

    internal void new_game ()
    {
        best_score = 0;
        last_moves_count = 0;
        generate_moves_menu ();
    }

    private uint last_moves_count = 0;
    internal void set_moves_count (uint moves_count)
    {
        update_state (/* label     */ get_moves_count_string (ref moves_count),
                      /* sensitive */ (moves_count != 0) || (best_score != 0));
        last_moves_count = moves_count;
    }
}
