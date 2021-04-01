using Gtk;

namespace KMWriter {
    public class Markdown {
        private Regex is_link;
        private Gtk.TextTag markdown_link;
        private Gtk.TextTag markdown_url;

        private Gtk.TextView view;
        private Gtk.TextBuffer buffer;

        public Markdown () {
            // Initialize regex
            is_link = new Regex ("\\[([^\\[]+?)\\](\\([^\\)\\n]+?\\))", RegexCompileFlags.CASELESS, 0);

            // Paranoia, initialize to null
            markdown_link = null;
            markdown_url = null;
        }

        public bool attach (TextView textview) {
            // Validate the view and buffer exist
            if (textview == null) {
                return false;
            }

            view = textview;
            buffer = view.get_buffer ();
            if (buffer == null) {
                view = null;
                return false;
            }

            buffer.notify["cursor-position"].connect (find_links);

            // Link Styles
            markdown_link = buffer.create_tag ("markdown-link");
            markdown_link.background = "#acf3ff";
            markdown_link.background_set = true;
            markdown_url = buffer.create_tag ("markdown-url");
            markdown_url.invisible = true;
            markdown_url.invisible_set = true;

            return true;
        }

        public void detach () {
            // Disconnect from events
            buffer.notify["cursor-position"].disconnect (find_links);

            buffer = null;
            view = null;
        }

        private void find_links () {
            if (buffer == null || markdown_link == null || markdown_url == null) {
                return;
            }

            Gtk.TextIter buffer_start, buffer_end, cursor_location;
            buffer.get_bounds (out buffer_start, out buffer_end);
            buffer.remove_tag (markdown_link, buffer_start, buffer_end);
            buffer.remove_tag (markdown_url, buffer_start, buffer_end);
            var cursor = buffer.get_insert ();
            buffer.get_iter_at_mark (out cursor_location, cursor);
            // We want to include invisible characters, more on that later
            string buffer_text = buffer.get_text (buffer_start, buffer_end, true);
    
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
                        buffer.get_iter_at_offset (out start_text_iter, start_text_pos);
                        buffer.get_iter_at_offset (out end_text_iter, end_text_pos);
                        buffer.get_iter_at_offset (out start_url_iter, start_url_pos);
                        buffer.get_iter_at_offset (out end_url_iter, end_url_pos);
    
                        // Skip if our cursor is inside the URL text
                        if (cursor_location.in_range (start_text_iter, end_url_iter)) {
                            continue;
                        }
    
                        // Apply our styling
                        buffer.apply_tag (markdown_link, start_text_iter, end_text_iter);
                        buffer.apply_tag (markdown_url, start_url_iter, end_url_iter);
                    }
                } while (matches.next ());
            }
        }
    }
}