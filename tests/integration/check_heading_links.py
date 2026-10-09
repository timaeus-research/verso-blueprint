"""Render ordinary split/nested chapters; validate actual heading link targets."""
from collections import Counter
from html.parser import HTMLParser
from pathlib import Path
import subprocess
import tempfile
from urllib.parse import unquote, urljoin, urlparse

PACKAGE_ROOT = Path(__file__).resolve().parents[2]


class Page(HTMLParser):
    def __init__(self, text):
        super().__init__()
        self.base = ""
        self.ids = []
        self.links = []
        self.headings = []
        self.awaiting_titlepage = False
        self.titlepage_heading = None
        self.feed(text)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "div" and "titlepage" in attrs.get("class", "").split():
            self.awaiting_titlepage = True
        if tag == "h1" and self.awaiting_titlepage:
            self.titlepage_heading = attrs
            self.awaiting_titlepage = False
        if "id" in attrs:
            self.ids.append(attrs["id"])
        if tag == "base":
            self.base = attrs.get("href", "")
        if tag == "a" and "href" in attrs:
            self.links.append(attrs["href"])
        if tag in ("h1", "h2", "h3", "h4"):
            self.headings.append(attrs.get("id"))


def main():
    subprocess.run(["python3", "scripts/apply-verso-patches.py", ".lake/packages/verso"],
                   cwd=PACKAGE_ROOT, check=True)
    with tempfile.TemporaryDirectory(prefix="blueprint-heading-test.") as tmp:
        output = Path(tmp) / "site"
        subprocess.run(["./scripts/lean-low-priority", "lake", "lean", "tests/HeadingLinkMain.lean",
                        "--", "--run", "tests/HeadingLinkMain.lean", "--output", str(output)],
                       cwd=PACKAGE_ROOT, check=True)
        root = output / "html-multi"
        pages = {p.relative_to(root).as_posix(): Page(p.read_text()) for p in root.rglob("index.html")}
        assert "Chapter/index.html" in pages
        assert "Chapter/Nested/index.html" in pages
        assert "Another-chapter/Nested/index.html" in pages
        for path, page in pages.items():
            assert "" not in page.ids, (path, "empty ID")
            assert all(n == 1 for n in Counter(page.ids).values()), (path, "duplicate IDs")
        for name, heading in (("Chapter/index.html", "Heading-links--Chapter"),
                              ("Chapter/Nested/index.html", "Heading-links--Chapter--Nested"),
                              ("Another-chapter/Nested/index.html", "Heading-links--Another-chapter--Nested")):
            assert heading in pages[name].headings, (name, "missing split-page heading ID")
        # Navigation has its own untagged headings; do not mistake them for the
        # chapter title. The root title-page h1 intentionally remains untagged.
        assert pages["index.html"].titlepage_heading is not None
        assert "id" not in pages["index.html"].titlepage_heading
        assert len([x for x in pages["Chapter/Nested/index.html"].headings if x]) >= 2
        checked = 0
        for prefix in ("/", "/nested/blueprint/"):
            base = "https://fixture.invalid" + prefix
            for path, page in pages.items():
                page_base = urljoin(base + path, page.base)
                for href in page.links:
                    link = urlparse(urljoin(page_base, href))
                    if link.netloc != "fixture.invalid" or not link.fragment or not link.path.startswith(prefix):
                        continue
                    target = unquote(link.path[len(prefix):])
                    target = target + "index.html" if target.endswith("/") else target
                    if target not in pages:
                        continue
                    assert unquote(link.fragment) in pages[target].ids, (path, href, target)
                    checked += 1
        assert checked > 0
        print(f"Heading links: {len(pages)} pages, {checked} resolved fragments; no duplicate/empty IDs.")


if __name__ == "__main__":
    main()
