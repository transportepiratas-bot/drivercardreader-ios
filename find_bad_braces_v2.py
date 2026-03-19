
def check_braces(filename):
    with open(filename, 'r', encoding='utf-8') as f:
        content = f.read()
    
    stack = []
    line_no = 1
    char_no = 0
    
    for i, char in enumerate(content):
        if char == '\n':
            line_no += 1
            char_no = 0
        else:
            char_no += 1
            
        if char == '{':
            stack.append((line_no, char_no))
        elif char == '}':
            if not stack:
                print(f"Extra closing brace at line {line_no}, col {char_no}")
                return False
            stack.pop()
            
    if stack:
        for line, col in stack:
            print(f"Unclosed opening brace at line {line}, col {col}")
        return False
        
    print("Braces are balanced!")
    return True

if __name__ == "__main__":
    check_braces('DDDParser.swift')
