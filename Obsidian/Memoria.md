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