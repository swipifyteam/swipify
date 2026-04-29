import requests
import sys

def main():
    try:
        response = requests.get("http://localhost:8000/")
        if response.status_code == 200:
            print("Backend is healthy")
            sys.exit(0)
        else:
            print(f"Backend returned status code {response.status_code}")
            sys.exit(1)
    except Exception as e:
        print(f"Failed to connect to backend: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
