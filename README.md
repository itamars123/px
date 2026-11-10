# נחש את המילה

A Hebrew word-guessing game in plain HTML, CSS and JavaScript, with no build step.

Guess the secret 4-letter Hebrew word in 6 tries. After each guess the tiles change color:

- **Teal:** the letter is in the word, in the right spot.
- **Orange:** the letter is in the word, in a different spot.
- **Gray:** the letter is not in the word.

## Play

Open `index.html` in a browser.

- Type on the on-screen keyboard, on a Hebrew keyboard, or on an English keyboard (it maps to the standard Israeli layout).
- Final letters (ך ם ן ף ץ) are handled for you.
- Your stats (games played, win rate, streaks and how many guesses each win took) are saved in the browser.

## Files

| File | Purpose |
| --- | --- |
| `index.html` | Page layout, help and stats dialogs |
| `sss.css` | Styles, animations, dark mode |
| `ssdas.js` | Game logic and word list (`WORDS`); add more 4-letter words there |
