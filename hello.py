#/usr/bin/env python3
from curses import window
import PySimpleGUI as sg
layout = [[sg.Button('Hello, New Stack', size=(30,4))]]
window = sg.Window('GUI SAMPLE', layout, size=(200,100))
event, values = window.read()
