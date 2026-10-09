"""Resolve native source links against actual Verso page bases under subpaths."""

from html.parser import HTMLParser
from pathlib import Path
import subprocess
import tempfile
from urllib.parse import urljoin


PACKAGE_ROOT = Path(__file__).resolve().parents[2]


class SourceLinks(HTMLParser):
    def __init__(self):
        super().__init__()
        self.base = None
        self.links = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "base":
            self.base = attrs.get("href")
        if tag == "a" and "bp_source_ref_pdf" in attrs.get("class", "").split():
            self.links.append(attrs["href"])


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp:
        output = Path(tmp) / "site"
        subprocess.run(
            ["./scripts/lean-low-priority", "lake", "lean", "tests/SourceLinkMain.lean",
             "--", "--run", "tests/SourceLinkMain.lean", "--output", str(output)],
            cwd=PACKAGE_ROOT, check=True,
        )
        root = output / "html-multi"
        nested = root / "Chapter" / "Nested" / "index.html"
        parser = SourceLinks()
        parser.feed(nested.read_text(encoding="utf-8"))
        assert parser.base is not None, "Missing native page base"
        assert parser.links, "Missing rendered source PDF links"
        for deployment in ("https://example.org/", "https://example.org/anchor/",
                           "https://example.org/nested/anchor/"):
            page_url = deployment + nested.relative_to(root).as_posix()
            base_url = urljoin(page_url, parser.base)
            for href in parser.links:
                actual = urljoin(base_url, href)
                expected = deployment + "source/paper.pdf#page=5"
                assert actual == expected, (page_url, parser.base, href, actual, expected)
        print("Source PDF links resolve correctly at root and nested deployment prefixes.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
