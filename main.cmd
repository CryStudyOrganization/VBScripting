@echo off
setlocal enabledelayedexpansion

:: Отримання аргументів командного рядка
set "LogFile=%~1"            
set "PathToFiles=%~2"        
set "ProcessName=%~3"        
set "ArchivePath=%~4"        
set "ComputerIP=%~5"         
set "LogFileSizeLimit=%~6"   

:: Встановлення кодування UTF-8 для коректного відображення тексту.
chcp 65001 > nul              

:: 2) Перевіряє чи існує файл, ім’я якого завдано у Аргумент1.
:: 3) Якщо не існує, то створює його. Це буде log файл скрипта.
:: 4) Дописує у цей файл :
::   - поточну дату та час;
::   - «Файл з ім’ям Аргумент1 відкрито або створено».
if not exist "%LogFile%" (
    echo %date% %time% > "%LogFile%"
    echo "2,3,4) Файл з ім'ям %LogFile% відкрито або створено." >> "%LogFile%"
)

:: 5) Отримання часу від сервера NTP та запис його в лог
w32tm /resync /force >> "%LogFile%"
echo "5) Час оновлено з сервера NTP." >> "%LogFile%"

:: 6) Виведення списку запущених процесів в лог
tasklist >> "%LogFile%"
echo "6) Список запущених процесів записано в лог." >> "%LogFile%"

:: 7) Завершення процесу з назвою, переданою через Аргумент 3
taskkill /IM "%ProcessName%" /F >> "%LogFile%"
echo "7) Процес %ProcessName% завершено." >> "%LogFile%"


:: 8) Видалення файлів за вказаним шляхом з розширенням .TMP або початок назви "temp"
:: Ініціалізація лічильника видалених файлів
set "fileCount=0"
for /r "%PathToFiles%" %%f in (*.tmp *.TMP temp*) do (
    del "%%f"
    set /a fileCount+=1
)

:: 9)  Інформацію про виконані дії записує у log файл. Вказати кількість видалених файлів.
echo "8, 9)Видалено %fileCount% файлів в %PathToFiles% з розширенням .TMP або назвою, починаючи з 'temp'." >> "%LogFile%"

:: 10) Стиск усіх залишених файлів за Аргументом 2 в .zip архів. Ім'я архіву - поточна дата та час.
set "currentDate=%date:~6,4%%date:~3,2%%date:~0,2%_%time:~0,2%%time:~3,2%"
set "archiveName=%currentDate%.zip"
powershell -noprofile -command "Compress-Archive -Path %PathToFiles%\* -DestinationPath %archiveName%"

:: 11) Перепис створеного архіву до теки, вказаної через Аргумент 4
move "%archiveName%" "%ArchivePath%" >> "%LogFile%"
echo "10-11) Створено та переміщено архів %archiveName% до %ArchivePath%." >> "%LogFile%"

:: 12, 13) Перевірка існування архіву за попередній день та запис результату в лог
set "prevDate=%date:~6,4%%date:~3,2%%date:~0,2%" 
if not exist "%ArchivePath%\!prevDate!.zip" (
  echo "12,13) Вчорашній архів відсутній." >> "%LogFile%"
) else (
  echo "12,13) Вчорашній архів знайдено." >> "%LogFile%"
)

:: 14. Перевірка існування та видалення архівів старіших за 30 днів
forfiles /P "%ArchivePath%" /M *.zip /D -30 /C "cmd /c del @file" >> "%LogFile%"
echo "14) Видалення архівів старіших за 30 днів завершено." >> "%LogFile%"

:: 15. Перевірка підключення до Інтернету та запис результату в лог
ping 8.8.8.8 -n 1 > nul
if errorlevel 1 (
    echo "15) Відсутнє підключення до Інтернету." >> "%LogFile%"
) else (
    echo "15) Підключення до Інтернету наявне." >> "%LogFile%"
)

:: 16. Перевірка наявності комп'ютера з вказаною IP-адресою та завершення його роботи
ping %ComputerIP% -n 1 > nul
if not errorlevel 1 (
    shutdown /s /m \\%ComputerIP% /t 0
    echo "16) Процес на комп'ютері з IP %ComputerIP% завершено." >> "%LogFile%"
) else (
    echo "16) Комп'ютер з IP %ComputerIP% недоступний." >> "%LogFile%"
)

:: 17. Отримання списку комп'ютерів в мережі та запис цієї інформації в лог
arp -a >> "%LogFile%"
echo "17) Список комп'ютерів в мережі записано в лог." >> "%LogFile%"

:: 18. Перевірка відсутності комп'ютерів зі списку у файлі ipon.txt в мережі та запис результату в лог
for /f %%i in (ipon.txt) do (
    ping %%i -n 1 > nul
    if errorlevel 1 (
        echo "18) Комп'ютер з IP %%i відсутній у мережі." >> "%LogFile%"
    )
)

:: 19. Перевірка розміру поточного лог-файлу та надсилання повідомлення на email, якщо розмір перевищено
if !LogFileSize! GTR %LogFileSizeLimit% (
  echo "19) Перевищено ліміт розміру лог-файлу." >> "%LogFile%"
)

:: 20. Перевірка кількості вільного та зайнятого простору на всіх дисках та запис цієї інформації в лог
wmic logicaldisk get caption, FreeSpace, Size >> "%LogFile%"
echo "20) Інформація про диски записана в лог-файл." >> "%LogFile%"

:: 21. Запис результатів виконання команди systeminfo у файл “systeminfo+поточна дата-час.txt”
set "SystemInfoFile=systeminfo_%date:~6,4%%date:~3,2%%date:~0,2%_%time:~0,2%%time:~3,2%.txt"
systeminfo > "%SystemInfoFile%"
echo "21) Результат виконання команди systeminfo записано у файл %SystemInfoFile%." >> "%LogFile%"
