@echo off

:: Starte das erste Skript
start /wait "Skript 1" 1_save_config.bat

:: Starte das zweite Skript
start "Skript 2" 2_main_dialog.bat