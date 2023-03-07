import torch
import numpy as np
import sys

print("\ntorch",torch.__file__)
print("numpy",np.__file__)
device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
print("device:", device)
device = torch.device("cpu")
print("cpu device:", device)
device = torch.device("cuda:0")
print("gpu device:", device)
torch.cuda.get_device_name(device)
print("Device name: ", torch.cuda.get_device_name(device))
print("Device properties: ", torch.cuda.get_device_properties(device))
print("Device_count: ", torch.cuda.device_count())

print("\nA quick test with tensor.")
x = torch.tensor(np.array(1), device='cuda')
print(x.device)
x = torch.tensor(np.array(1), device='cpu')
print(x.device) 
x = torch.tensor(1, device='cuda:0')
print(x.device)

print("===================================\n")
print("Set Device cuda:1")
device = torch.device("cuda:1")
print("gpu device:", device)
x = torch.tensor(1, device='cuda:1')
print(x.device)
x = torch.tensor(np.array(1), device='cuda:1')
print(x.device)
print("Device name: ", torch.cuda.get_device_name(device))
print("Device properties: ", torch.cuda.get_device_properties(device))
print("Device_count: ", torch.cuda.device_count())
print("===================================\n")

print("Try using cuda.set_device")
device=torch.cuda.set_device("cuda:0")
print("Device name: ", torch.cuda.get_device_name(device))
print("Device properties: ", torch.cuda.get_device_properties(device))
print("Device_count: ", torch.cuda.device_count())
x = torch.tensor(1, device="cuda:0")
print(x.device)

