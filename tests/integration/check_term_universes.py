"""Native block/inline universe regression, including rendered token metadata."""
from html.parser import HTMLParser
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


class Terms(HTMLParser):
    def __init__(self, text):
        super().__init__()
        self.codes = []
        self.current = None
        self.feed(text)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "code" and "lean" in attrs.get("class", "").split():
            self.current = {"text": "", "hover": 0, "binding": 0}
        if self.current is not None:
            self.current["hover"] += "data-verso-hover" in attrs
            self.current["binding"] += "data-binding" in attrs

    def handle_data(self, data):
        if self.current is not None:
            self.current["text"] += data

    def handle_endtag(self, tag):
        if tag == "code" and self.current is not None:
            self.codes.append(self.current)
            self.current = None


def main():
    subprocess.run(["python3", "scripts/apply-verso-patches.py", ".lake/packages/verso"], cwd=ROOT, check=True)
    with tempfile.TemporaryDirectory(prefix="blueprint-term-universes.") as tmp:
        subprocess.run(["./scripts/lean-low-priority", "lake", "lean", "tests/TermUniversesMain.lean",
                        "--", "--run", "tests/TermUniversesMain.lean", "--output", tmp], cwd=ROOT, check=True)
        text = (Path(tmp) / "html-multi/index.html").read_text()
        codes = Terms(text).codes
        expressions = [c for c in codes if "fun" in c["text"] and "Type" in c["text"]]
        assert len(expressions) == 3, expressions
        assert all(c["hover"] > 0 and c["binding"] > 0 for c in expressions), expressions
        assert "Type v" in expressions[-1]["text"], expressions
        print("Term universes: inline and both native blocks render with contextual hover/binding metadata.")


if __name__ == "__main__":
    main()
