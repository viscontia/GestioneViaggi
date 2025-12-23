
import os
import re

def update_dialog_options(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Pattern for new DialogOptions { ... }
    # We want to inject BackdropClick = false if not present
    
    modified = False

    def replace_options(match):
        full_match = match.group(0)
        braces_content = match.group(1) if match.group(1) else ""
        
        if "BackdropClick" in braces_content:
            # Already set, ensure it is false? 
            # If user explicitly set it, maybe we enable it? But user request said "User cannot click outside".
            # So force false.
            return re.sub(r'BackdropClick\s*=\s*(true|false)', 'BackdropClick = false', full_match)
        
        # Not present, inject it
        if braces_content.strip() == "":
             # Case: new DialogOptions { }
             return "new DialogOptions { BackdropClick = false }"
        else:
             # Case: new DialogOptions { Foo = bar }
             # Insert at beginning
             return f"new DialogOptions {{ BackdropClick = false, {braces_content} }}"

    # Regex 1: new DialogOptions { ... }
    # Handle multi-line support for braces content if needed, but usually it's one line in this codebase
    # Using dotall for multi-line support
    new_content = re.sub(r'new DialogOptions\s*\{([^}]*)\}', replace_options, content, flags=re.DOTALL)
    
    if new_content != content:
        modified = True
        content = new_content

    # Regex 2: new DialogOptions without braces (usually just new DialogOptions)
    # Be careful not to match matched ones from Regex 1 (which now have braces)
    # Look for new DialogOptions NOT followed by {
    def replace_no_braces(match):
        return "new DialogOptions { BackdropClick = false }"

    new_content_2 = re.sub(r'new DialogOptions(?!\s*\{)', replace_no_braces, content)

    if new_content_2 != content:
        modified = True
        content = new_content_2

    if modified:
        print(f"Updating {file_path}")
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)

base_dir = '/Users/adrianovisconti/Documents/Sviluppo Software/MAUI/GestioneViaggi/Components'
for root, dirs, files in os.walk(base_dir):
    for file in files:
        if file.endswith('.razor'):
            update_dialog_options(os.path.join(root, file))
