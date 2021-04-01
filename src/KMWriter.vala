namespace KMWriter{
    public class KMWriterApp : Gtk.Application {
        private Gtk.SourceView source_view;
        private Gtk.SourceBuffer source_buffer;
        private Markdown markdown_enrichment;
        private Grammar grammar_enrichment;

        protected override void activate () {
            // Grab application Window
            var window = new Gtk.ApplicationWindow (this);
            window.set_title ("1.6km Writer");
            window.set_default_size (600, 320);

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

            // Attach markdown enrichment
            markdown_enrichment = new Markdown ();
            markdown_enrichment.attach (source_view);

            // Attach grammar checker
            grammar_enrichment = new Grammar ();
            grammar_enrichment.attach (source_view);

            window_removed.connect (() => {
                grammar_enrichment.detach ();
                markdown_enrichment.detach ();
            });

            // Populate the Window
            window.add (scroll_box);
            window.show_all ();
        }

        public static int main (string[] args) {
            return new KMWriterApp ().run (args);
        }
    }
}