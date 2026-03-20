Yep — that fits a “latent config bug + something changed today” situation.
Most likely what changed today is not your dotfiles, but one of these runtime conditions:
- tmux server restarted today, so it re-read tmux/.config/tmux/tmux.conf:13 and started exporting TERM=xterm-ghostty inside tmux
- Ghostty had already updated earlier and now identifies itself as xterm-ghostty instead of a more generic term
- opencode got stricter about terminal capability detection, so the wrong inner TERM now shows up as broken UI instead of “mostly works”
Why that matters:
- tmux is a server; it keeps running across shells/windows until you kill it
- so you can have the same config for months, but only notice a break the day the tmux server is recreated under a different outer terminal environment
- with your current config, behavior depends on what $TERM was at the moment tmux started
That’s why “same config on many machines” and “it only broke today” can both be true.
Your current setup is effectively:
- outside tmux: TERM=xterm-ghostty — correct
- inside tmux: also TERM=xterm-ghostty — incorrect, but only newly obvious when tmux/opencode/Ghostty line up the wrong way
A very plausible timeline is:
- before: tmux server was old, or outer terminal was xterm-256color, or opencode was less sensitive
- today: tmux server restarted under Ghostty, inherited xterm-ghostty, and now opencode renders badly
Quick read-only checks you can do:
- echo $TERM outside tmux
- inside tmux: echo $TERM
- tmux show -gv default-terminal
- tmux kill-server then start tmux again and see if behavior reproduces consistently
If you want, I can map out the exact “what changed today” diagnosis path next, or give you the robust tmux settings that stop this from ever depending on startup timing again.
▣  Plan · gpt-5.4 · 44.0s
but also it doesn't just break in opencode. My starship shell prompt breaks, my tmux theme is breaking
Thinking: Investigating font issues in tmux
I need to figure out whether there’s a font or Unicode mismatch in tmux. I should inspect the tmux status and check the locale and UTF-8 options to see if something isn’t supported. It seems like my starship prompt appears broken, and glyphs show correctly outside of tmux. However, when inside tmux, I notice logos are represented as box characters. So, I wonder if a fallback font is causing this issue or if it’s something else with tmux's configuration?
Thinking: Analyzing potential font and glyph issues
I suspect there are some misalignments with braille or block characters due to the locale being set to C.UTF-8. My starship prompt may be breaking because of powerline separators being misaligned, likely due to tmux not properly handling UTF-8. I need to inspect the terminfo to see if it's set up correctly for UTF-8. If tmux's terminal type is set incorrectly, all applications might struggle with escape sequences and width calculations, causing issues like icons rendering improperly.
Thinking: Exploring font and character set issues
I'm starting to think that the tofu might indicate a missing font rather than a TERM issue. It's possible that opencode is intentionally switching to an alternate character set due to incorrect smacs/rmacs settings. I noticed that the logo looked like it was transformed into box drawing characters, which could happen if the terminal received a sixel. I need to consider this as I think through the user's question.
Yeah — that actually strengthens the tmux diagnosis, not weakens it.
If opencode, Starship, and your tmux theme all break at once only inside tmux, the shared failure point is tmux’s terminal identity/capabilities layer.
What’s happening:
- outside tmux, apps talk directly to Ghostty, so TERM=xterm-ghostty is correct
- inside tmux, apps should see tmux’s terminal type, not Ghostty’s
- your config forces the inside value to the outside one in tmux/.config/tmux/tmux.conf:13
That can break all three classes of UI:
- Starship: uses Nerd Font glyphs, separators, colors, cursor-positioning assumptions
- tmux theme: uses special separators/icons and depends on correct width/color handling
- opencode: full-screen TUI, so it is the most sensitive to bad terminal capabilities
So this is not “just opencode being weird” — it is exactly what I’d expect when tmux lies about TERM.
Why the tmux theme can break too:
- tmux itself renders the status line using its own understanding of the terminal
- if default-terminal / terminal feature negotiation is wrong, separators, colors, width, and Unicode rendering can get weird
- your config is also internally inconsistent:
  - tmux/.config/tmux/tmux.conf:2 sets screen-256color
  - tmux/.config/tmux/tmux.conf:13 overrides it with ${TERM}
  - tmux/.config/tmux/tmux.conf:3 only adds RGB for xterm-256color, not xterm-ghostty
So tmux is currently in a bad middle state:
- not using a stable tmux-internal terminal type
- not applying the right feature override for Ghostty
- depending on whatever outer terminal happened to launch the tmux server
That combination absolutely can make prompt separators, tmux status modules, and TUIs all look broken together.
Most likely fix direction:
- remove set -g default-terminal "${TERM}"
- use set -g default-terminal "tmux-256color" if available
- add proper feature handling for Ghostty, e.g. a terminal-features entry for xterm-ghostty
- restart the tmux server completely
If you want, I can give you a precise no-guesswork patch plan next:
1. minimal safe tmux fix
2. slightly more modern tmux/Ghostty fix
3. diagnosis checklist first, then patch after you confirm outputs
▣  Plan · gpt-5.4 · 28.9s
what do I need to do for the conf to work with ghostty and basically any other popular terminal? Also is the conf setup for scrolling
Thinking: Planning tmux configuration
I need to come up with a plan for addressing the tmux scrolling configuration. I might check if the configuration file already includes a mouse setting. It’s possible that we need to mention both mouse and scrolling for a complete answer. I could also provide insights on the default copy-mode mouse settings. Regarding third-party tools like ghostty, I could ask if the user wants me to apply any necessary patches later. For now, I think I'm good without additional tools.
Yes — you can make this tmux config work cleanly with Ghostty and basically every modern terminal, and the fix is straightforward.
What to change in principle:
- Use a stable tmux-internal terminal type: set default-terminal to tmux-256color when available, otherwise screen-256color
- Remove set -g default-terminal "${TERM}" from tmux/.config/tmux/tmux.conf:13; that is the main portability bug
- Advertise truecolor to tmux based on the outer terminal via terminal-features, not by pretending tmux is the outer terminal
- Add Ghostty to the feature list, since your current tmux/.config/tmux/tmux.conf:3 only covers xterm-256color
A good portable direction is:
- set -g default-terminal "tmux-256color"
- set -as terminal-features ",xterm-ghostty:RGB,ghostty:RGB,xterm-256color:RGB,alacritty:RGB,wezterm:RGB,kitty:RGB,foot:RGB,st-256color:RGB"
- optionally keep a fallback override for older tmux setups, but terminal-features is the cleaner modern approach
Why this works:
- inside tmux, applications correctly target tmux
- tmux still knows the outer terminal supports RGB/truecolor
- Ghostty, WezTerm, Kitty, Alacritty, and generic xterm-style terminals all behave consistently
About scrolling in your current config:
- right now your config is not really set up for modern tmux mouse scrolling
- tmux/.config/tmux/tmux.conf does not enable mouse on
- so wheel scrolling likely won’t behave the way most people expect inside tmux panes/history
- with mouse off, scrolling generally depends on terminal scrollback only when tmux isn’t using the alternate screen; once a full-screen app or tmux history is involved, it feels inconsistent
If you want good scrolling behavior, the usual plan is:
- enable set -g mouse on
- rely on tmux copy-mode/history for scrolling inside tmux
- keep terminal emulator scrollback for content outside tmux/full-screen apps
Recommended plan:
1. remove the ${TERM} override
2. switch to tmux-256color
3. add terminal-features entries including xterm-ghostty
4. enable mouse on if you want natural scroll-wheel behavior
5. restart tmux completely with tmux kill-server
One note:
- tmux-256color needs to exist in terminfo on each machine; on most modern systems it does, but if not, fall back to screen-256color
If you want, I can next give you:
1. a minimal cross-terminal tmux config snippet, or
2. a slightly more polished version including scrolling/mouse behavior and safer defaults for older machines.
▣  Plan · gpt-5.4 · 17.7s
or clicking
Thinking: Addressing user interface tasks
I want to provide a clear response regarding how the user can interact, especially with scrolling or clicking. I'll focus on read-only mode and suggest addressing ongoing tasks. If the mouse mode in tmux is off, I might need to explain that clicking isn’t possible. I don’t think it’s necessary to ask for preferences unless I’m unsure. I should remind the user about options like pane selection or copy mode in a concise way.
Yes — for scrolling and clicking, tmux needs explicit mouse support.
- Your current tmux/.config/tmux/tmux.conf does not enable mouse, so scroll wheel and click behavior will be limited/inconsistent.
- Without mouse on, tmux usually won’t handle:
  - wheel scrolling through pane history
  - clicking to select/switch panes
  - resizing panes with the mouse
  - selecting windows in some status line setups
- With mouse on, tmux will handle those interactions much more like you expect in Ghostty, WezTerm, Kitty, Alacritty, etc.
A few nuances:
- Scrolling: with mouse on, wheel scrolling enters tmux history/copy-mode instead of only using the terminal emulator’s own scrollback.
- Clicking: pane focus/switching works; selecting text can feel different because tmux may capture the mouse first.
- Links: terminal-native URL clicking can be reduced inside tmux depending on app mode, but tools like your tmux-fzf-url plugin help.
- Selection: many terminals have a modifier for native selection passthrough, like Shift + drag/click.
For a portable setup, the plan is:
- fix terminal identity first: stop setting inner TERM to ${TERM}
- set default-terminal to tmux-256color
- add terminal-features entries for Ghostty and common terminals
- enable set -g mouse on
That gives you:
- correct rendering for Starship/opencode/tmux theme
- working scroll wheel
- working pane clicking
- better cross-terminal behavior overall
If you want, I can next give you a clean recommended tmux snippet that covers:
1. Ghostty + other popular terminals
2. truecolor
3. scrolling and clicking
4. sane fallback behavior for older machines
