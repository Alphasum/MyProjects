#/usr/bin/env python3
import tkinter as tk
from tkinter import simpledialog
ROOT = tk.Tk()
ROOT.withdraw()
USER_INP = simpledialog.askstring(title="Input Test", prompt="Type your name:")
print("Hello", USER_INP)
