public class KMWriter : Gtk.Application {
    private Gtk.SourceView source_view;
    private Gtk.SourceBuffer source_buffer;
    private Regex is_link;
    private TimedMutex scheduler;
    private const int REDRAW_DELAY_IN_MS = 250;
    private Gtk.TextTag markdown_link;
    private Gtk.TextTag markdown_url;

    protected override void activate () {
        // Grab application Window
        var window = new Gtk.ApplicationWindow (this);
        window.set_title ("1.6km Writer");
        window.set_default_size (600, 320);

        // Initialize regex
        is_link = new Regex ("\\[([^\\[]+?)\\](\\([^\\)\\n]+?\\))", RegexCompileFlags.CASELESS, 0);

        // Scroll view to hold contents
        var scroll_box = new Gtk.ScrolledWindow (null, null);
        // Get a pointer to the Markdown Language
        var manager = Gtk.SourceLanguageManager.get_default ();
        var language = manager.guess_language (null, "text/markdown");

        // Create a GtkSourceView and create a markdown buffer
        source_view = new Gtk.SourceView ();
        source_view.margin = 0;
        source_buffer = new Gtk.SourceBuffer.with_language (language);
        source_buffer.highlight_syntax = true;
        source_view.set_buffer (source_buffer);
        source_view.set_wrap_mode (Gtk.WrapMode.WORD);
        // Set placeholder text
        source_buffer.text = "# Hello from 1.6km Writer\nDelete this text and start writing!";
        // Add the GtkSourceView to the Scroll Box
        scroll_box.add (source_view);

        // Link Styles
        markdown_link = source_buffer.create_tag ("markdown-link");
        markdown_link.background = "#acf3ff";
        markdown_link.background_set = true;
        markdown_url = source_buffer.create_tag ("markdown-url");
        markdown_url.invisible = true;
        markdown_url.invisible_set = true;

        source_buffer.notify["cursor-position"].connect (find_links);

        // Populate the Window
        window.add (scroll_box);
        window.show_all ();
    }

    private void find_links () {
        Gtk.TextIter buffer_start, buffer_end, cursor_location;
        source_buffer.get_bounds (out buffer_start, out buffer_end);
        source_buffer.remove_tag (markdown_link, buffer_start, buffer_end);
        source_buffer.remove_tag (markdown_url, buffer_start, buffer_end);
        var cursor = source_buffer.get_insert ();
        source_buffer.get_iter_at_mark (out cursor_location, cursor);
        // We want to include invisible characters, more on that later
        string buffer_text = source_buffer.get_text (buffer_start, buffer_end, true);

        // Check for links
        MatchInfo matches;
        if (is_link.match_full (buffer_text, buffer_text.length, 0, 0, out matches)) {
            do {
                int start_text_pos, end_text_pos;
                int start_url_pos, end_url_pos;
                bool have_text = matches.fetch_pos (1, out start_text_pos, out end_text_pos);
                bool have_url = matches.fetch_pos (2, out start_url_pos, out end_url_pos);

                if (have_text && have_url) {
                    // Convert byte offset to character offset in buffer (in case of emoji or unicode)
                    start_text_pos = buffer_text.char_count ((ssize_t) start_text_pos);
                    end_text_pos = buffer_text.char_count ((ssize_t) end_text_pos);
                    start_url_pos = buffer_text.char_count ((ssize_t) start_url_pos);
                    end_url_pos = buffer_text.char_count ((ssize_t) end_url_pos);

                    // Convert the character offsets to TextIter's
                    Gtk.TextIter start_text_iter, end_text_iter, start_url_iter, end_url_iter;
                    source_buffer.get_iter_at_offset (out start_text_iter, start_text_pos);
                    source_buffer.get_iter_at_offset (out end_text_iter, end_text_pos);
                    source_buffer.get_iter_at_offset (out start_url_iter, start_url_pos);
                    source_buffer.get_iter_at_offset (out end_url_iter, end_url_pos);

                    // Skip if our cursor is inside the URL text
                    if (cursor_location.in_range (start_text_iter, end_url_iter)) {
                        continue;
                    }

                    // Apply our styling
                    source_buffer.apply_tag (markdown_link, start_text_iter, end_text_iter);
                    source_buffer.apply_tag (markdown_url, start_url_iter, end_url_iter);
                }
            } while (matches.next ());
        }
    }

    public class TimedMutex {
        private bool can_action;
        private Mutex droptex;
        private int delay;

        public TimedMutex (int milliseconds_delay = 1500) {
            if (milliseconds_delay < 100) {
                milliseconds_delay = 100;
            }

            delay = milliseconds_delay;
            can_action = true;
            droptex = Mutex ();
        }

        public bool can_do_action () {
            bool res = false;

            if (droptex.trylock()) {
                if (can_action) {
                    res = true;
                    can_action = false;
                }
                Timeout.add (delay, clear_action);
                droptex.unlock ();
            }
            return res;
        }

        private bool clear_action () {
            droptex.lock ();
            can_action = true;
            droptex.unlock ();
            return false;
        }
    }

    public static int main (string[] args) {
        return new KMWriter ().run (args);
    }
}