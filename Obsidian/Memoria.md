Para instalar arduino en arch lo que he hecho ha sido usar:

	yay -S arduino-ide-bin

Tambien he tenido que descargar un paquete de python que faltaba

	sudo pacman -S python-pyserial

He encontrado problemas a la hora de comunicarme con la placa porque no tenía permisos de lectura/escritura:

	sudo chmod 666 /dev/ttyUSB0

**ES POSIBLE QUE HAYA QUE PONERLE PERMISOS DE EJECUCIÓN**

	sudo chmod 777 /dev/ttyUSB0

Al parecer cada vez que conecto la placa hay que darle permisos.

He conseguido usar los leds de la placa.

Acabo de conectar  los pines del ADC HX717 ([[hx711F_EN.pdf]]) a la placa con unos cables a los pines correspondientes.

VCC -> VDD5V (PIN 15)
DAT -> IO9 (GPIO0) (PIN 27)
SCK -> SPICLK (PIN 21)
GND -> GND (PIN 14)

![[Pasted image 20240130220222.png]]

Los pines usados anteriormente no funcionan correctamente ya que no se usa el reloj del protocolo SPI, en vez de eso usamos otro pin que se gestiona a través de un GPIO.

Actualmente los pines conectados son:

VCC -> VDD5V (PIN 15)
DAT -> IO2 (PIN 3)
SCK -> IO3 (PIN 4)
GND -> GND (PIN 14)

Para el desarrollo del software que usa la placa, vamos a usar dos ejemplos que vienen en arduino, el de BLE_uart de los ejemplos de ESP32, y el ejemplo de la librería de Bogdan Necula para el conversor analogico digital Hx711.

https://randomnerdtutorials.com/esp32-save-data-permanently-preferences/

*Desarrollar como hemos buscado los componentes*

Para componentes
	https://jlcpcb.com/
	Que es de donde vamos a comprar el chip
	https://www.mouser.es/ (Para buscar componentes de manera mas cómoda)

Para el procesador
	https://github.com/espressif/kicad-libraries?tab=readme-ov-file

Kicad
- [x] ESP32C3-Mini-1-4N
	https://jlcpcb.com/partdetail/EspressifSystems-ESP32_C3_MINI_1N4/C2838502
- [x] USB-C (connector)
	https://jlcpcb.com/partdetail/ShouHan-TYPE_C_16PIN_2MD_073/C2765186
- [x] Protección ESD (A la salida del USB) 
	https://jlcpcb.com/partdetail/TechPublic-USBLC62P6/C2827693
- [x] Regulador (RT9080) 
	https://jlcpcb.com/partdetail/RichtekTech-RT908033GJ5/C841192
- [x] HX717 
	https://jlcpcb.com/partdetail/Avia_Semicon_xiamen-HX717/C575394
- [ ] LED(s)  
- [ ] Switch(es)  
- [ ] Resistencias  
- [ ] Condensadores  
- [ ] Jumper (no pedir soldados)  
- [ ] Conexiones externas (Para la barra/algún GPIO extra/3V3/GND).  
- [ ] Potencial configuración de los pines de strapping. (Depende de la datasheet del esp32) 
- [ ] Entrada de 5V externa (aparte del USB).  
- [ ] Poner testpoints  
- [ ] Silkscreen

GPIO 2,8,9 peligro porque son para modos de boot
Mirar esp32-C3FN4 datasheet

![[Pasted image 20240624133946.png]]