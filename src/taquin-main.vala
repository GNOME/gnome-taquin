/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-

   This file is part of GNOME Taquin.

   Copyright (C) 2014-2020 – Arnaud Bonatti <arnaud.bonatti@gmail.com>

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

using Gtk;

private class Taquin : Gtk.Application, BaseApplication
{
    /* Translators: application name, as used in the window manager, the window title, the about dialog... */
    internal const string PROGRAM_NAME = _("Taquin");

    /* Settings */
    private GLib.Settings settings;
    private static int tmp_size = 0;
    private GameType? tmp_type = null;
    private bool size_changed = false;
    private bool theme_changed = false;
    private static bool? sound = null;

    /* Widgets */
    private GameWindow window;
    private TaquinView view;
    private NewGameScreen new_game_screen;
    private HistoryButton history_button_1;
    private HistoryButton history_button_2;
    private GLib.Menu size_menu_fifteen;
    private GLib.Menu size_menu_sixteen;

    /* The game being played */
    private Game? game = null;
    List<string> theme_dirlist;

    private const OptionEntry [] option_entries =
    {
        /* Translators: command-line option description, see 'gnome-taquin --help' */
        { "fifteen", 0, OptionFlags.NONE, OptionArg.NONE, null,        N_("Play the classical 1880s’ 15-puzzle"), null },

        /* Translators: command-line option description, see 'gnome-taquin --help' */
        { "sixteen", 0, OptionFlags.NONE, OptionArg.NONE, null,        N_("Try this fun alternative 16-puzzle"), null },

        /* Translators: command-line option description, see 'gnome-taquin --help' */
        { "size", 's', OptionFlags.NONE, OptionArg.INT, ref tmp_size,  N_("Sets the puzzle edges’ size (3-5, 2-9 for debug)"),

        /* Translators: in the command-line options description, text to indicate the user should specify a size, see 'gnome-taquin --help' */
                                                                       N_("SIZE") },

        /* Translators: command-line option description, see 'gnome-taquin --help' */
        { "mute", 0, OptionFlags.NONE, OptionArg.NONE, null,           N_("Turn off the sound"), null },

        /* Translators: command-line option description, see 'gnome-taquin --help' */
        { "unmute", 0, OptionFlags.NONE, OptionArg.NONE, null,         N_("Turn on the sound"), null },

        /* Translators: command-line option description, see 'gnome-taquin --help' */
        { "version", 'v', OptionFlags.NONE, OptionArg.NONE, null,      N_("Print release version and exit"), null },

        /* Translators: command-line option description, see 'gnome-taquin --help' */
     /* { "no-gtk", 0, 0, OptionArg.NONE, null,         N_("Begins a console game"), null}, TODO */
        {}
    };

    private const GLib.ActionEntry [] action_entries =
    {
        /* these two are for actions defined in the desktop file, when using D-Bus activation */
        {"fifteen", play_fifteen_game},
        {"sixteen", play_sixteen_game},

        /* TODO SimpleActionChangeStateCallback is deprecated...
        {"change-size", null, "s", null, null, change_size_cb},     http://valadoc.org/#!api=gio-2.0/GLib.SimpleActionChangeStateCallback
        {"change-theme", null, "s", null, null, change_theme_cb},   see comments about window.add_action (settings.create_action (…)) */

        {"change-size", change_size_cb, "s"},
        {"change-theme", change_theme_cb, "s"},

        {"set-use-night-mode", set_use_night_mode, "b"},
        {"quit", quit}
    };

    private static int main (string [] args)
    {
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (GETTEXT_PACKAGE);

        Environment.set_application_name (PROGRAM_NAME);
        Window.set_default_icon_name ("org.gnome.Taquin");

        return new Taquin ().run (args);
    }

    private Taquin ()
    {
        Object (application_id: "org.gnome.Taquin", flags: ApplicationFlags.FLAGS_NONE);

        add_main_option_entries (option_entries);
    }

    protected override int handle_local_options (GLib.VariantDict options)
    {
        if (options.contains ("version"))
        {
            /* NOTE: Is not translated so can be easily parsed */
            stdout.printf ("%1$s %2$s\n", "gnome-taquin", VERSION);
            return Posix.EXIT_SUCCESS;
        }

        if (tmp_size != 0 && tmp_size < 2)
            tmp_size = 2;

        if (options.contains ("mute"))
            sound = false;
        else if (options.contains ("unmute"))
            sound = true;

        if (options.contains ("fifteen"))
            tmp_type = GameType.FIFTEEN;
        else if (options.contains ("sixteen"))
            tmp_type = GameType.SIXTEEN;

        return -1;
    }

    protected override void startup()
    {
        base.startup ();

        settings = new GLib.Settings ("org.gnome.Taquin");
        if ((sound != null) || (tmp_size > 1) || (tmp_type != null))
        {
            settings.delay ();
            if (sound != null)
                settings.set_boolean ("sound", (!) sound);
            if (tmp_size > 1)
                settings.set_int ("size", tmp_size);
            if (tmp_type != null)
                settings.set_string ("type", ((!) tmp_type).to_string ());     // TODO better?
            settings.apply ();
        }

        /* UI parts */
        view = new TaquinView ();

        size_menu_fifteen = new GLib.Menu ();
        /* Translators: when configuring a new game, entry in the menu of the game size menubutton; the "\t" is a tabulation; after is indicated an estimated time for solving the puzzle (1 minute) */
        size_menu_fifteen.append (_("3 × 3\t1 minute"), "app.change-size('3')");

        /* Translators: when configuring a new game, entry in the menu of the game size menubutton; the "\t" is a tabulation; after is indicated an estimated time for solving the puzzle (5 minutes) */
        size_menu_fifteen.append (_("4 × 4\t5 minutes"), "app.change-size('4')");

        /* Translators: when configuring a new game, entry in the menu of the game size menubutton; the "\t" is a tabulation; after is indicated an estimated time for solving the puzzle (15 minutes) */
        size_menu_fifteen.append (_("5 × 5\t15 minutes"), "app.change-size('5')");
        size_menu_fifteen.freeze ();

        size_menu_sixteen = new GLib.Menu ();
        /* Translators: when configuring a new game, entry in the menu of the game size menubutton; the "\t" is a tabulation; after is indicated an estimated time for solving the puzzle (1 minute) */
        size_menu_sixteen.append (_("3 × 3\t1 minute"), "app.change-size('3')");

        /* Translators: when configuring a new game, entry in the menu of the game size menubutton; the "\t" is a tabulation; after is indicated an estimated time for solving the puzzle (5 minutes) */
        size_menu_sixteen.append (_("4 × 4\t3 minutes"), "app.change-size('4')");

        /* Translators: when configuring a new game, entry in the menu of the game size menubutton; the "\t" is a tabulation; after is indicated an estimated time for solving the puzzle (5 minutes) */
        size_menu_sixteen.append (_("5 × 5\t5 minutes"), "app.change-size('5')");
        size_menu_sixteen.freeze ();

        GLib.Menu theme_menu = new GLib.Menu ();
        /* Translators: when configuring a new game, entry in the menu of the game theme menubutton; play with cats images */
        theme_menu.append (_("Cats"), "app.change-theme('cats')");


        /* Translators: when configuring a new game, entry in the menu of the game theme menubutton; play with numbers */
        theme_menu.append (_("Numbers"), "app.change-theme('numbers')");
        theme_menu.freeze ();

        /* Translators: when configuring a new game, label of the first big button; name of the traditional Taquin game */
        new_game_screen = new NewGameScreen (_("15-Puzzle"),
                                             "app.type('fifteen')",

        /* Translators: when configuring a new game, label of the second big button; name of the non-traditional game */
                                             _("16-Puzzle"),
                                             "app.type('sixteen')");

        settings.changed ["type"].connect (() => {
                new_game_screen.update_menubutton_menu (NewGameScreen.MenuButton.ONE,
                                                        (GameType) settings.get_enum ("type") == GameType.FIFTEEN ? size_menu_fifteen :
                                                                                                                    size_menu_sixteen);
            });
        new_game_screen.update_menubutton_menu (NewGameScreen.MenuButton.ONE,
                                                (GameType) settings.get_enum ("type") == GameType.FIFTEEN ? size_menu_fifteen :
                                                                                                            size_menu_sixteen);
        new_game_screen.update_menubutton_menu (NewGameScreen.MenuButton.TWO,
                                                theme_menu);

        history_button_1 = new HistoryButton ();
        history_button_2 = new HistoryButton ();
        history_button_1.show ();
        history_button_2.show ();

        /* Window */
        init_night_mode ();
        window = new GameWindow ("/org/gnome/Taquin/ui/taquin.css",
                                 PROGRAM_NAME,
                                 _("About Taquin"),
                                 /* start now */ true,     // TODO add an option to go to new-game screen?
                                 GameWindowFlags.SHOW_START_BUTTON
                                 | GameWindowFlags.HAS_SOUND
                                 | GameWindowFlags.SHORTCUTS
                                 | GameWindowFlags.SHOW_HELP,
                                 (Box) new_game_screen,
                                 view,
                                 null,  // appearance menu
                                 history_button_1,
                                 history_button_2,
                                 night_light_monitor);
        window.play.connect (start_game);
        window.back.connect (back_cb);
        window.undo.connect (undo_cb);
        window.restart.connect (restart_cb);

        set_accels_for_action ("base.copy",             {        "<Primary>c"       });
        set_accels_for_action ("base.copy-alt",         { "<Shift><Primary>c"       });
        set_accels_for_action ("ui.new-game",           {        "<Primary>n"       });
        set_accels_for_action ("ui.start-or-restart",   { "<Shift><Primary>n"       });
        set_accels_for_action ("app.quit",              {        "<Primary>q",
                                                          "<Shift><Primary>q"       });
        set_accels_for_action ("base.paste",            {        "<Primary>v"       });
        set_accels_for_action ("base.paste-alt",        { "<Shift><Primary>v"       });
        set_accels_for_action ("ui.undo",               {        "<Primary>z"       });
     // set_accels_for_action ("ui.restart" // TODO
     // set_accels_for_action ("ui.redo",               { "<Shift><Primary>z"       });
        set_accels_for_action ("base.escape",           {                 "Escape"  });
        set_accels_for_action ("base.toggle-hamburger", {                 "F10",
                                                                          "Menu"    });
//        set_accels_for_action ("app.help",              {                 "F1"      });
//        set_accels_for_action ("base.about",            {          "<Shift>F1"      });
        set_accels_for_action ("win.show-help-overlay", {                 "F1", // TODO test: if showing Yelp fails, should fallback there
                                                                 "<Primary>F1",
                                                          "<Shift><Primary>F1",
                                                                 "<Primary>question",
                                                          "<Shift><Primary>question"});

        /* New-game screen signals */
        settings.changed ["size"].connect (() => {
            if (!size_changed)
                update_size_button_label (settings.get_int ("size") /* 2 <= size <= 9 */);
            size_changed = false;
        });
        update_size_button_label (settings.get_int ("size") /* 2 <= size <= 9 */);

        settings.changed ["theme"].connect (() => {
            if (!theme_changed)
                update_theme (settings.get_string ("theme"));
            theme_changed = false;
        });
        update_theme (settings.get_string ("theme"));

        add_action_entries (action_entries, this);
        add_action (settings.create_action ("sound"));
        add_action (settings.create_action ("type"));        // TODO window action?
        // TODO window.add_action (settings.create_action ("size"));        // Problem: cannot use this way for an integer from a menu; works for radiobuttons in Iagno
        // TODO window.add_action (settings.create_action ("theme"));

        if (settings.get_boolean ("sound"))
            init_sound ();

        add_window (window);
    }

    protected override void activate ()
    {
        if (game == null)
            start_game ();
        window.present ();
    }

    private void play_fifteen_game ()
    {
        if (game == null)
        {
            settings.set_string ("type", "fifteen");
            start_game ();
        }
        window.present ();
    }

    private void play_sixteen_game ()
    {
        if (game == null)
        {
            settings.set_string ("type", "sixteen");
            start_game ();
        }
        window.present ();
    }

    protected override void shutdown ()
    {
        window.destroy ();
        base.shutdown ();
    }

    /*\
    * * Night mode
    \*/

    NightLightMonitor night_light_monitor;  // keep it here or it is unrefed

    private void init_night_mode ()
    {
        night_light_monitor = new NightLightMonitor ("/org/gnome/taquin/");
    }

    private void set_use_night_mode (SimpleAction action, Variant? gvariant)
        requires (gvariant != null)
    {
        night_light_monitor.set_use_night_mode (((!) gvariant).get_boolean ());
    }

    /*\
    * * Creating and starting game
    \*/

    private void start_game ()
    {
        if (game != null)
        {
            SignalHandler.disconnect_by_func ((!) game, null, this);
            SignalHandler.disconnect_by_func ((!) game, null, window);
        }

        history_button_1.new_game ();
        history_button_2.new_game ();

        GameType type = (GameType) settings.get_enum ("type");
        int8 size = (int8) settings.get_int ("size"); /* 2 <= size <= 9 */
        game = new Game (type, size);
        set_window_title ();
        view.game = (!) game;
        window.move_done (0);
        history_button_1.set_moves_count (0);
        history_button_2.set_moves_count (0);
        move_done = false;

        string filename = "";
        List<weak string> dirlist = theme_dirlist.copy ();
        do
        {
            int random = Random.int_range (0, (int) dirlist.length());
            filename = dirlist.nth_data(random);
            unowned List<weak string> entry = dirlist.find_custom (filename, strcmp);
            dirlist.remove_link (entry);
        } while (filename[0] == '0' || (filename[0] != '1' && filename[0] != size.to_string ()[0] && dirlist.length () != 0));
        view.theme = Path.build_filename (DATA_DIRECTORY, "themes", settings.get_string ("theme"), filename);
        view.realize ();        // TODO does that help?

        ((!) game).complete.connect (game_complete_cb);
        ((!) game).bad_click.connect (bad_click_cb);
        ((!) game).move.connect (move_cb);
    }

    private void set_window_title ()
    {
        /* Translators: name of one of the games, as displayed in the headerbar when playing */
        window.update_title (((!) game).game_type == GameType.FIFTEEN ? _("15-Puzzle")

        /* Translators: name of one of the games, as displayed in the headerbar when playing */
                                                                      : _("16-Puzzle"));
    }

    /*\
    * * Signals from window
    \*/

    private void restart_cb ()
        requires (game != null)
    {
        ((!) game).restart ();
        play_sound (Sound.SLIDING_N);
        move_done = false;
    }

    private void back_cb ()
        requires (game != null)
    {
        set_window_title ();
    }

    private void undo_cb ()
        requires (game != null)
    {
        ((!) game).undo ();
        play_sound (Sound.SLIDING_1);
    }

    /*\
    * * Signals from game
    \*/

    private void move_cb (bool x_axis, int8 number, int8 x_gap, int8 y_gap, uint moves_count, bool disable_animation)
    {
        window.move_done (moves_count);
        history_button_1.set_moves_count (moves_count);
        history_button_2.set_moves_count (moves_count);
        play_sound (Sound.SLIDING_1);   // TODO sliding-n??
        move_done = true;
    }

    private void game_complete_cb ()
    {
        window.finish_game ();
        play_sound (Sound.GAME_OVER);
        string best_score_string;
        history_button_1.save_best_score (out best_score_string);
        history_button_2.save_best_score (out best_score_string);
        window.show_notification (best_score_string);
    }

    private bool move_done = false;
    private void bad_click_cb (Game.BadClick reason, bool keyboard_call)
    {
        switch (reason)
        {
            case Game.BadClick.NOT_MOVING:
                /* Translators: in-window notification; on the 15-Puzzle game, if the user clicks a tile that cannot move */
                window.show_notification (_("You can’t move this tile!"));
                return;

            case Game.BadClick.USE_ARROWS:
                if (move_done)  // do nothing if a move has already been done, a bad click or key press happens; reset on next game
                    return;

                if (keyboard_call)
                    /* Translators: in-window notification; on the 16-Puzzle game, help for keyboard use, displayed if the user uses an unmeaningful keyboard key */
                    window.show_notification (_("Use Shift and an arrow to move tiles!"));

                else
                    /* Translators: in-window notification; on the 16-Puzzle game, if the user clicks on a tile of the board (the game is played using mouse with arrows around the board) */
                    window.show_notification (_("Click on the arrows to move tiles!"));

                return;

            case Game.BadClick.IS_OUTSIDE:  // TODO something?
            case Game.BadClick.EMPTY_TILE:  // TODO something?
            default:
                return;
        }
    }

    /*\
    * * Options of the start-screen
    \*/

    private void change_size_cb (SimpleAction action, Variant? variant)
        requires (variant != null)
    {
        size_changed = true;
        int size = int.parse (((!) variant).get_string ());
        update_size_button_label (size /* 3 <= size <= 5 */);
        settings.set_int ("size", size);
    }
    private void update_size_button_label (int size)
    {
        new_game_screen.update_menubutton_label (NewGameScreen.MenuButton.ONE,
                                                 NewGameScreen.get_size_button_label (size));
    }

    private void change_theme_cb (SimpleAction action, Variant? variant)
        requires (variant != null)
    {
        update_theme (((!) variant).get_string ());
    }
    private void update_theme (string theme_id)
    {
        theme_changed = true;
        if (_update_theme (theme_id))
            settings.set_string ("theme", theme_id);
        else
        {
            if (!_update_theme ("cats"))
                assert_not_reached ();
            settings.set_string ("theme", "cats");
        }
    }
    private bool _update_theme (string theme_id)
    {
        new_game_screen.update_menubutton_label (NewGameScreen.MenuButton.TWO,
                                                 get_theme_button_label (theme_id));

        Dir dir;
        theme_dirlist = new List<string> ();
        bool success = false;
        try
        {
            dir = Dir.open (Path.build_filename (DATA_DIRECTORY, "themes", theme_id));
            while (true)
            {
                string? filename = dir.read_name ();
                if (filename == null)
                    break;
                theme_dirlist.append ((!) filename);
            }
            success = true;
        }
        catch (FileError e)
        {
            warning ("Failed to load images: %s", e.message);
        }
        return success;
    }
    private static inline string get_theme_button_label (string theme_id)
    {
        switch (theme_id)
        {
            /* Translators: when configuring a new game, button label for the theme, if the current theme is Cats */
            case "cats":    return _("Theme: Cats ▾");

            /* Translators: when configuring a new game, button label for the theme, if the current theme is Numbers */
            case "numbers": return _("Theme: Numbers ▾");

            /* Translators: when configuring a new game, button label for the theme, if the current theme has been added by the user; the %s is replaced by the theme name */
            default:        return _("Theme: %s ▾").printf (theme_id);
        }
    }

    /*\
    * * Sound
    \*/

    private GSound.Context sound_context;
    private SoundContextState sound_context_state = SoundContextState.INITIAL;

    private enum Sound
    {
        SLIDING_1,
        SLIDING_N,
        GAME_OVER;
    }

    private enum SoundContextState
    {
        INITIAL,
        WORKING,
        ERRORED;
    }

    private void init_sound ()
     // requires (sound_context_state == SoundContextState.INITIAL)
    {
        try
        {
            sound_context = new GSound.Context ();
            sound_context_state = SoundContextState.WORKING;
        }
        catch (Error e)
        {
            warning (e.message);
            sound_context_state = SoundContextState.ERRORED;
        }
    }

    private void play_sound (Sound sound)
    {
        if (settings.get_boolean ("sound"))
        {
            if (sound_context_state == SoundContextState.INITIAL)
                init_sound ();
            if (sound_context_state == SoundContextState.WORKING)
                _play_sound (sound, sound_context);
        }
    }

    private static void _play_sound (Sound sound, GSound.Context sound_context)
     // requires (sound_context_state == SoundContextState.WORKING)
    {
        string name;
        switch (sound)
        {
            case Sound.SLIDING_1:
                name = "sliding-1.ogg";
                break;
            case Sound.SLIDING_N:
                name = "sliding-n.ogg";
                break;
            case Sound.GAME_OVER:
                name = "gameover.ogg";
                break;
            default:
                return;
        }
        string path = Path.build_filename (SOUND_DIRECTORY, name);
        try
        {
            sound_context.play_simple (null, GSound.Attribute.MEDIA_NAME, name,
                                             GSound.Attribute.MEDIA_FILENAME, path);
        }
        catch (Error e)
        {
            warning (e.message);
        }
    }

    /*\
    * * Copy action
    \*/

    internal void copy (string text)
    {
        Gdk.Display? display = Gdk.Display.get_default ();
        if (display == null)
            return;

        Gtk.Clipboard clipboard = Gtk.Clipboard.get_default ((!) display);
        clipboard.set_text (text, text.length);
    }

    /*\
    * * about dialog infos
    \*/

    internal void get_about_dialog_infos (out string [] artists,
                                          out string [] authors,
                                          out string    comments,
                                          out string    copyright,
                                          out string [] documenters,
                                          out string    logo_icon_name,
                                          out string    program_name,
                                          out string    translator_credits,
                                          out string    version,
                                          out string    website,
                                          out string    website_label)
    {
        /* Translators: about dialog text */
        comments = _("A classic 15-puzzle game");

        artists = {
        /* Translators: about dialog text crediting an artist (a photograph), with the website where the image was published */
            _("Abelard (Wikimedia)"), _("Alvesgaspar (Wikimedia)"), _("Mueller-rech.muenchen (Wikimedia)"),
            _("Ruskis (Wikimedia)"), _("Toyah (Wikimedia)"),

        /* Translators: about dialog text; in the Credits, text at the end of the "Artwork by" section */
            _("(see COPYING.themes for information)")
        };

        /* Translators: about dialog text crediting an author */
        authors = { _("Arnaud Bonatti") };


        /* Translators: about dialog text crediting a maintainer; the %u are replaced with the years of start and end */
        copyright = _("Copyright \xc2\xa9 %u-%u – Arnaud Bonatti").printf (2014, 2020);


        /* Translators: about dialog text crediting a documenter */
        documenters = { _("Arnaud Bonatti") };
        logo_icon_name = "org.gnome.Taquin";
        program_name = PROGRAM_NAME;

        /* Translators: about dialog text; this string should be replaced by a text crediting yourselves and your translation team, or should be left empty. Do not translate literally! */
        translator_credits = _("translator-credits");
        version = VERSION;

        website = "https://wiki.gnome.org/Apps/Taquin";
        /* Translators: about dialog text; label of the website link */
        website_label = _("Page on GNOME wiki");
    }
}
