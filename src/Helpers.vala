namespace KMWriter {
    public string strip_markdown (string sentence) {
        string result = sentence;
        try {
            Regex is_link = new Regex ("\\[([^\\[]+?)\\](\\([^\\)\\n]+?\\))", RegexCompileFlags.CASELESS, 0);
            result = is_link.replace_eval (
                result,
                (ssize_t) result.length,
                0,
                RegexMatchFlags.NOTEMPTY,
                (match_info, result) =>
                {
                    var title = match_info.fetch (1);
                    result.append (title);
                    return false;
                });

            result = result.replace ("*", "");
            result = result.replace ("[", "");
            result = result.replace ("]", "");
            result = result.replace ("_", "");
            while (result.has_prefix ("\n") || result.has_prefix ("#") || result.has_prefix (">") || result.has_prefix (" ")) {
                result = result.substring (1);
            }
        } catch (Error e) {
            warning ("Could not strip markdown: %s", e.message);
        }

        return result;
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
}