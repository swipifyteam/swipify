import os
import re

def replace_with_opacity(dir_path):
    # Regex to match .withOpacity(...)
    # We use non-greedy matching to get the value inside the parentheses
    pattern = re.compile(r'\.withOpacity\(([^)]+)\)')

    for root, dirs, files in os.walk(dir_path):
        for file in files:
            if file.endswith('.dart'):
                file_path = os.path.join(root, file)
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()

                # Perform the replacement
                new_content = pattern.sub(r'.withValues(alpha: \1)', content)

                if content != new_content:
                    with open(file_path, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    print(f"Updated {file_path}")

if __name__ == "__main__":
    replace_with_opacity('lib')
