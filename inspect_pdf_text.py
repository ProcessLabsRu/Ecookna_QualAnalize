import re
import pdfplumber
import logging
import sys

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Re-use regexes from PDFParser
NUMBER_RE = re.compile(r"(\d{2}-\d{3}-\s*\d{4}\/\d+\/\d+(?:[\/\w-]*))")
ANCHOR_RE = re.compile(r"(\d+)\s*[x×хХ]\s*(\d+)\s+(\d+)\s+([\d.,]+)\s+([\d.,]+)")
SPLIT_RE = re.compile(r"Итого по изделию:", re.IGNORECASE)

def inspect_pdf(file_path):
    print(f"Inspecting {file_path}...")
    try:
        with pdfplumber.open(file_path) as pdf:
            full_text = []
            for page in pdf.pages:
                text = page.extract_text()
                if text:
                    full_text.append(text)
            text = "\n".join(full_text)
    except Exception as e:
        print(f"Error reading PDF: {e}")
        return

    print("--- FULL TEXT START ---")
    print(text)
    print("--- FULL TEXT END ---")

    blocks = SPLIT_RE.split(text)
    for block_idx, block in enumerate(blocks):
        print(f"\n=== BLOCK {block_idx} ===")
        anchors = list(ANCHOR_RE.finditer(block))
        last_end = 0
        
        for i, anchor in enumerate(anchors):
            print(f"-- Anchor {i} found at {anchor.start()} --")
            print(f"Anchor content: {anchor.group(0)}")
            
            pre_context_full = block[last_end:anchor.start()]
            print(f"Pre-context full: '{pre_context_full}'") # Show newlines etc

            num_matches = list(NUMBER_RE.finditer(pre_context_full))
            if num_matches:
                num_match = num_matches[-1]
                print(f"Number found: {num_match.group(1)}")
                
                raw_formula_chunk = pre_context_full[num_match.end():].strip()
                print(f"Raw Formula Chunk: '{raw_formula_chunk}'")
                
                raw_formula_clean = re.sub(r"\s+", " ", raw_formula_chunk).strip()
                print(f"Clean Formula Chunk: '{raw_formula_clean}'")

                if " " in raw_formula_clean:
                    position_formula = raw_formula_clean.split(" ")[-1]
                else:
                    position_formula = raw_formula_clean
                print(f"Extracted Formula: '{position_formula}'")

            else:
                print("NO NUMBER FOUND in pre-context")
            
            last_end = anchor.end()

if __name__ == "__main__":
    file_path = "docs/examples/тест11022026.pdf"
    if len(sys.argv) > 1:
        file_path = sys.argv[1]
    inspect_pdf(file_path)
