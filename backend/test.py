import urllib.request
try:
    print(urllib.request.urlopen('http://localhost:8000/users/WmXnaKZ7qZXZx8KRKPKrfHXVCDp2').read())
except Exception as e:
    print(e.read())
