import serial
import struct
import numpy as np
import matplotlib.pyplot as plt


PORT = "COM3"
BAUD = 115200
TIMEOUT = 10

try:
    ser = serial.Serial(PORT, BAUD, timeout=TIMEOUT)
    ser.reset_input_buffer() 
    ser.reset_output_buffer()
except Exception as e:
    print(f"Port açılamadı: {e}")
    exit()

print("Veri bekleniyor...KEY2'ye basın.")

expected_bytes = 784 * 4
data = ser.read(expected_bytes)

if len(data) < expected_bytes:
    print(f"Eksik veri geldi! Beklenen: {expected_bytes}, Gelen: {len(data)}")

else:
    print("Veri başarıyla alındı.")
    try:
        values = struct.unpack('>784f', data)
        
        # Numpy array'e çevirme ve matris yapısına çevirme
        img = np.array(values).reshape(28, 28)

        # Terminal
        np.set_printoptions(precision=3, suppress=True, linewidth=200)
        print("\n28x28 Matris Görüntüsü:\n")
        print(img)

        # grafik
        plt.figure(figsize=(8, 6))
        plt.imshow(img, cmap='Greys', interpolation='none') 
        plt.title("FPGA İçeriği (28x28)")
        plt.colorbar(label='Float Değeri')
        plt.show()

        # CSV Kaydet
        np.savetxt("sram_dump.csv", img, delimiter=",", fmt="%.5f")
        print("\nVeriler 'sram_dump.csv' dosyasına kaydedildi.")

    except Exception as e:
        print(f"Veri işleme hatası: {e}")

ser.close()
print("Bağlantı kapatıldı.")