using Gtk;
namespace KMWriter {
    public class TagUpdateRequest {
        public int cursor_offset;
        public int text_offset;
        public string text;
        public TextTag tag;

        public static int compare_tag_requests (TagUpdateRequest a, TagUpdateRequest b) {
            if ((a.cursor_offset == b.cursor_offset) &&
                (a.text_offset == b.text_offset) &&
                (a.text == b.text) &&
                (a.tag == b.tag))
            {
                return 0;
            }

            if (a.text != b.text) {
                return strcmp (a.text, b.text);
            }

            if (a.text_offset != b.text_offset) {
                return a.text_offset - b.text_offset;
            }

            if (a.cursor_offset != b.cursor_offset) {
                return a.cursor_offset - b.cursor_offset;
            }

            // Tags are different?
            return -1;
        }
    }

    public class Grammar {
        private TimedMutex grammar_timer;
        private TextTag grammar_error;

        private Gtk.TextView view;
        private Gtk.TextBuffer buffer;
        
        // Threading State
        private Thread<void> grammar_processor;
        private Mutex processor_check;
        private bool processor_running;
        private Gee.ConcurrentSet<TagUpdateRequest> send_to_processor;
        private Gee.ConcurrentSet<TagUpdateRequest> send_to_buffer;

        // Caching
        public const int CACHE_SIZE = 50;
        // Only cache invalid elements because that's what's visually wrong
        public Gee.LinkedList<string> invalid_sentences;

        public Grammar () {
            // Timed Mutex to limit update rate
            grammar_timer = new TimedMutex ();

            // Should be null, but just to be certain
            grammar_error = null;

            // Initialize thread state
            processor_check = Mutex ();
            processor_running = false;
            grammar_processor = null;
            send_to_processor = new Gee.ConcurrentSet<TagUpdateRequest> (TagUpdateRequest.compare_tag_requests);
            send_to_buffer = new Gee.ConcurrentSet<TagUpdateRequest> (TagUpdateRequest.compare_tag_requests);
            invalid_sentences = new Gee.LinkedList<string> ();
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

            buffer.changed.connect (check_grammar);

            // Grammar Styles
            grammar_error = buffer.create_tag ("grammar-error");
            grammar_error.background = "#00a367";
            grammar_error.background_set = true;
            grammar_error.foreground = "#eeeeee";
            grammar_error.foreground_set = true;

            GLib.Idle.add (update_buffer);

            return true;
        }

        public void detach () {
            // Disconnect from events
            buffer.changed.disconnect (check_grammar);

            buffer = null;
            view = null;

            // Drain queues
            while (send_to_buffer.size != 0) {
                TagUpdateRequest requested = send_to_buffer.first ();
                send_to_buffer.remove (requested);
            }
            while (send_to_processor.size != 0) {
                TagUpdateRequest requested = send_to_processor.first ();
                send_to_processor.remove (requested);
            }
            if (grammar_processor != null) {
                grammar_processor.join ();
            }
        }

        private void start_worker () {
            processor_check.lock ();
            if (!processor_running) {
                if (grammar_processor != null) {
                    grammar_processor.join ();
                }

                grammar_processor = new Thread<void> ("grammar-processor", process_grammar);
                processor_running = true;
            }
            processor_check.unlock ();
        }

        private bool update_buffer () {
            if (buffer == null) {
                return false;
            }

            TextIter buffer_start, buffer_end, cursor_location;
            var cursor = buffer.get_insert ();
            buffer.get_iter_at_mark (out cursor_location, cursor);

            buffer.get_bounds (out buffer_start, out buffer_end);
            while (send_to_buffer.size != 0) {
                TagUpdateRequest requested = send_to_buffer.first ();
                send_to_buffer.remove (requested);

                // Check at the offset in the request
                TextIter check_start, check_end;
                buffer.get_iter_at_offset (out check_start, requested.text_offset);
                buffer.get_iter_at_offset (out check_end, requested.text_offset + requested.text.length);
                if (check_start.in_range (buffer_start, buffer_end) && 
                    check_end.in_range (buffer_start, buffer_end) && 
                    check_start.get_text (check_end) == requested.text)
                {
                    buffer.apply_tag (requested.tag, check_start, check_end);
                    continue;
                }

                int cursor_change = cursor_location.get_offset () - requested.cursor_offset;
                if (check_start.forward_chars (cursor_change)) {
                    buffer.get_iter_at_offset (out check_end, check_start.get_offset () + requested.text.length);
                    if (check_start.in_range (buffer_start, buffer_end) && 
                        check_end.in_range (buffer_start, buffer_end) && 
                        check_start.get_text (check_end) == requested.text)
                    {
                        buffer.apply_tag (requested.tag, check_start, check_end);
                        continue;
                    }
                }
            }

            while (invalid_sentences.size > CACHE_SIZE) {
                invalid_sentences.poll ();
            }

            return true;
        }

        private void process_grammar () {
            if (buffer == null) {
                return;
            }

            while (send_to_processor.size != 0) {
                TagUpdateRequest requested = send_to_processor.first ();
                send_to_processor.remove (requested);
                string sentence = strip_markdown (requested.text).chug ().chomp ();
                if (!grammar_correct_sentence_check (sentence)) {
                    send_to_buffer.add (requested);
                    if (!invalid_sentences.contains (sentence)) {
                        invalid_sentences.add (sentence);
                    }
                }
            }
            processor_running = false;
            Thread.exit (0);
            return;
        }

        private void check_grammar () {
            if (!grammar_timer.can_do_action ()) {
                return;
            }

            if (buffer == null) {
                return;
            }

            TextIter buffer_start, buffer_end, cursor_location;
            buffer.get_bounds (out buffer_start, out buffer_end);
            buffer.remove_tag (grammar_error, buffer_start, buffer_end);
            var cursor = buffer.get_insert ();
            buffer.get_iter_at_mark (out cursor_location, cursor);

            TextIter sentence_start = buffer_start.copy ();
            TextIter sentence_end = buffer_start.copy ();
            while (sentence_end.forward_sentence_end ()) {
                string sentence = buffer.get_text (sentence_start, sentence_end, false);
                if (!cursor_location.in_range (sentence_start, sentence_end)) {
                    string q_check = strip_markdown (sentence).chug ().chomp ();
                    if (invalid_sentences.contains (q_check)) {
                        buffer.apply_tag (grammar_error, sentence_start, sentence_end);
                    } else {
                        TagUpdateRequest request = new TagUpdateRequest () {
                            cursor_offset = cursor_location.get_offset (),
                            text_offset = sentence_start.get_offset (),
                            text = sentence,
                            tag = grammar_error
                        };
                        send_to_processor.add (request);
                    }
                }
                sentence_start = sentence_end;

                // Strip whitespace from start of sentence.
                while (sentence_start.get_char ().isspace ()) {
                    if (!sentence_start.forward_char ()) {
                        break;
                    }
                }
                sentence_end = sentence_start;
            }

            start_worker ();
        }

        private bool grammar_correct_sentence_check (string sentence) {
            bool error_free = false;

            string check_sentence = strip_markdown (sentence).chug ().chomp ();
            try {
                string[] command = {
                    "link-parser",
                    "-batch"
                };
                Subprocess grammar = new Subprocess.newv (
                    command,
                    SubprocessFlags.STDOUT_PIPE |
                    SubprocessFlags.STDIN_PIPE |
                    SubprocessFlags.STDERR_MERGE);

                var input_stream = grammar.get_stdin_pipe ();
                if (input_stream != null) {
                    DataOutputStream flush_buffer = new DataOutputStream (input_stream);
                    if (!flush_buffer.put_string (check_sentence)) {
                        warning ("Could not set buffer");
                    }
                    flush_buffer.flush ();
                    flush_buffer.close ();
                }
                var output_stream = grammar.get_stdout_pipe ();
                grammar.wait ();
                if (output_stream != null) {
                    var proc_input = new DataInputStream (output_stream);
                    string line = "";
                    while ((line = proc_input.read_line (null)) != null) {
                        error_free = error_free || line.down ().contains ("0 errors");
                    }
                }
            } catch (Error e) {
                warning ("Could not process output: %s", e.message);
            }
            return error_free;
        }
    }
}