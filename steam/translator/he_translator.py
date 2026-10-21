"""מתרגם מסך לעברית – עובד על כל משחק.

התוכנה צולמת אזור במסך (למשל חלון הדיאלוג של המשחק), מזהה את הטקסט באנגלית
בעזרת Tesseract OCR, מתרגמת אותו לעברית ומציגה את התרגום בחלון שקוף שנמצא תמיד מעל המשחק.

מקשים (אם ספריית keyboard מותקנת):
  F8  – השהה / המשך
  F9  – בחירת אזור חדש לתרגום
  F10 – יציאה
"""

import difflib
import os
import queue
import re
import sys
import threading
import time
import tkinter as tk

try:
    import mss
    import pytesseract
    from deep_translator import GoogleTranslator
    from PIL import Image, ImageOps
except ImportError as err:
    print("חסרה ספרייה:", err)
    print("הריצו קודם: python -m pip install -r requirements.txt")
    sys.exit(1)

try:
    import keyboard  # מקשים גלובליים – לא חובה
except ImportError:
    keyboard = None

INTERVAL_SECONDS = 1.0      # כל כמה זמן לבדוק אם הטקסט במסך השתנה
SIMILARITY_THRESHOLD = 0.9  # טקסט דומה מעל הסף הזה נחשב לאותו טקסט
FONT = ("Arial", 18, "bold")

# נתיב ברירת המחדל של Tesseract ב-Windows
WINDOWS_TESSERACT = r"C:\Program Files\Tesseract-OCR\tesseract.exe"
if os.name == "nt" and os.path.exists(WINDOWS_TESSERACT):
    pytesseract.pytesseract.tesseract_cmd = WINDOWS_TESSERACT

# בלי זה, ב-Windows עם הגדלת תצוגה (125%, 150%) הקואורדינטות של החלון ושל הצילום לא תואמות
if os.name == "nt":
    try:
        import ctypes
        ctypes.windll.shcore.SetProcessDpiAwareness(2)
    except Exception:
        pass


def clean_text(text):
    """מנקה את הפלט של ה-OCR: מאחד רווחים ושורות ומסיר תווים בודדים שהם רעש."""
    lines = [re.sub(r"\s+", " ", line).strip() for line in text.splitlines()]
    lines = [line for line in lines if len(re.sub(r"[^A-Za-z]", "", line)) >= 2]
    return " ".join(lines)


def is_new_text(text, previous):
    """האם הטקסט השתנה מספיק כדי לתרגם אותו שוב."""
    if not text:
        return False
    if not previous:
        return True
    return difflib.SequenceMatcher(None, text, previous).ratio() < SIMILARITY_THRESHOLD


def read_region(sct, region):
    """מצלם את האזור ומחזיר את הטקסט שזוהה בו."""
    shot = sct.grab(region)
    img = Image.frombytes("RGB", shot.size, shot.rgb)
    img = ImageOps.grayscale(img)
    img = img.resize((img.width * 2, img.height * 2))  # הגדלה משפרת מאוד את הזיהוי
    return clean_text(pytesseract.image_to_string(img, lang="eng"))


class Translator:
    def __init__(self):
        self.google = GoogleTranslator(source="auto", target="iw")
        self.cache = {}

    def translate(self, text):
        if text not in self.cache:
            self.cache[text] = self.google.translate(text)
        return self.cache[text]


def select_region(root):
    """פותח מסך שקוף שבו גוררים מלבן סביב הטקסט שרוצים לתרגם."""
    result = {}
    win = tk.Toplevel(root)
    win.attributes("-fullscreen", True)
    win.attributes("-alpha", 0.3)
    win.attributes("-topmost", True)
    win.configure(bg="black")
    canvas = tk.Canvas(win, cursor="cross", bg="black", highlightthickness=0)
    canvas.pack(fill="both", expand=True)
    canvas.create_text(
        win.winfo_screenwidth() // 2, 60, fill="white", font=FONT,
        text="גררו מלבן סביב הטקסט של המשחק (Esc לביטול)",
    )
    start = {}

    def on_down(e):
        start["x"], start["y"] = e.x_root, e.y_root
        start["rect"] = canvas.create_rectangle(e.x, e.y, e.x, e.y, outline="#66c0f4", width=3)

    def on_drag(e):
        canvas.coords(start["rect"], start["x"] - win.winfo_rootx(), start["y"] - win.winfo_rooty(), e.x, e.y)

    def on_up(e):
        left, top = min(start["x"], e.x_root), min(start["y"], e.y_root)
        width, height = abs(e.x_root - start["x"]), abs(e.y_root - start["y"])
        if width > 10 and height > 10:
            result["region"] = {"left": left, "top": top, "width": width, "height": height}
        win.destroy()

    canvas.bind("<ButtonPress-1>", on_down)
    canvas.bind("<B1-Motion>", on_drag)
    canvas.bind("<ButtonRelease-1>", on_up)
    win.bind("<Escape>", lambda e: win.destroy())
    win.focus_force()
    root.wait_window(win)
    return result.get("region")


class App:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("מתרגם מסך לעברית")
        self.root.overrideredirect(True)
        self.root.attributes("-topmost", True)
        self.root.attributes("-alpha", 0.88)
        self.root.configure(bg="#171a21")

        bar = tk.Frame(self.root, bg="#0038b8")
        bar.pack(fill="x")
        tk.Button(bar, text="✕", command=self.quit, bg="#0038b8", fg="white", bd=0).pack(side="left", padx=4)
        tk.Button(bar, text="בחר אזור (F9)", command=self.choose_region, bg="#0038b8", fg="white", bd=0).pack(side="left", padx=4)
        self.pause_btn = tk.Button(bar, text="השהה (F8)", command=self.toggle_pause, bg="#0038b8", fg="white", bd=0)
        self.pause_btn.pack(side="left", padx=4)
        title = tk.Label(bar, text="🇮🇱 מתרגם מסך – סטים בעברית", bg="#0038b8", fg="white")
        title.pack(side="right", padx=6)

        self.label = tk.Label(
            self.root, text="בחרו אזור במסך כדי להתחיל", font=FONT, fg="white", bg="#171a21",
            justify="right", anchor="e", wraplength=700, padx=12, pady=10,
        )
        self.label.pack(fill="both", expand=True)

        # גרירת החלון בעזרת סרגל הכותרת
        for widget in (bar, title):
            widget.bind("<ButtonPress-1>", self.start_move)
            widget.bind("<B1-Motion>", self.do_move)

        self.region = None
        self.paused = False
        self.running = True
        self.results = queue.Queue()
        self.translator = Translator()

        if keyboard:
            keyboard.add_hotkey("f8", lambda: self.root.after(0, self.toggle_pause))
            keyboard.add_hotkey("f9", lambda: self.root.after(0, self.choose_region))
            keyboard.add_hotkey("f10", lambda: self.root.after(0, self.quit))

        threading.Thread(target=self.worker, daemon=True).start()
        self.root.after(100, self.poll_results)
        self.root.after(300, self.choose_region)

    def start_move(self, e):
        self._dx, self._dy = e.x_root - self.root.winfo_x(), e.y_root - self.root.winfo_y()

    def do_move(self, e):
        self.root.geometry(f"+{e.x_root - self._dx}+{e.y_root - self._dy}")

    def choose_region(self):
        self.root.withdraw()
        region = select_region(self.root)
        self.root.deiconify()
        if region:
            self.region = region
            # מציבים את חלון התרגום מתחת לאזור שנבחר
            y = region["top"] + region["height"] + 10
            if y > self.root.winfo_screenheight() - 150:
                y = max(0, region["top"] - 160)
            self.label.configure(wraplength=max(400, region["width"]))
            self.root.geometry(f"+{region['left']}+{y}")
            self.label.configure(text="מחכה לטקסט...")

    def toggle_pause(self):
        self.paused = not self.paused
        self.pause_btn.configure(text="המשך (F8)" if self.paused else "השהה (F8)")

    def worker(self):
        """רץ ברקע: מצלם, מזהה ומתרגם. התוצאות עוברות לחלון דרך תור."""
        previous = ""
        with mss.mss() as sct:
            while self.running:
                region = self.region
                if region and not self.paused:
                    try:
                        text = read_region(sct, region)
                        if is_new_text(text, previous):
                            previous = text
                            self.results.put(self.translator.translate(text))
                    except Exception as err:  # שגיאת רשת או OCR – מציגים וממשיכים
                        self.results.put(f"שגיאה: {err}")
                time.sleep(INTERVAL_SECONDS)

    def poll_results(self):
        try:
            while True:
                self.label.configure(text=self.results.get_nowait())
        except queue.Empty:
            pass
        if self.running:
            self.root.after(100, self.poll_results)

    def quit(self):
        self.running = False
        self.root.destroy()

    def run(self):
        self.root.mainloop()


if __name__ == "__main__":
    App().run()
