"""Install a pinned Temurin JDK with the release's published SHA-256."""
import hashlib
import os
from pathlib import Path
import shutil
import tarfile
import tempfile
from urllib.request import urlopen

tools = Path(os.environ['NADA_TOOLS_DIR'])
destination = tools / 'jdk-17'
if not (destination / 'bin/javac').exists():
    if destination.exists():
        raise SystemExit('Existing JDK directory is incomplete; choose an unused NADA_TOOLS_DIR.')
    tools.mkdir(parents=True, exist_ok=True)
    url = ('https://github.com/adoptium/temurin17-binaries/releases/download/'
           'jdk-17.0.20.1%2B1/OpenJDK17U-jdk_x64_linux_hotspot_17.0.20.1_1.tar.gz')
    expected = '3808d1d15e3ec6bd5b84057fb5d84c33d8a1536a258146bcea2e603fc726e08e'
    with tempfile.TemporaryDirectory(dir=tools) as scratch:
        archive = Path(scratch) / 'jdk.tar.gz'
        digest = hashlib.sha256()
        with urlopen(url, timeout=60) as response, archive.open('wb') as output:
            while chunk := response.read(1024 * 1024):
                digest.update(chunk)
                output.write(chunk)
        if digest.hexdigest() != expected:
            raise SystemExit('JDK checksum mismatch; refusing to install.')
        extracted = Path(scratch) / 'unpacked'
        with tarfile.open(archive) as package:
            package.extractall(extracted, filter='data')
        roots = list(extracted.iterdir())
        if len(roots) != 1 or not (roots[0] / 'bin/javac').exists():
            raise SystemExit('Unexpected JDK archive layout.')
        shutil.move(roots[0], destination)
    print('Temurin JDK 17 installed; SHA-256 verified.')
