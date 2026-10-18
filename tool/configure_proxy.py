"""Configure Gradle's supported JVM proxy properties from injected proxy URLs."""
import os
import sys
import shlex
from pathlib import Path
from urllib.parse import urlsplit

proxy_url = os.environ.get("HTTPS_PROXY") or os.environ.get("HTTP_PROXY")
if proxy_url:
    proxy = urlsplit(proxy_url)
    if not proxy.hostname or proxy.username or proxy.password:
        raise SystemExit("A supported proxy without embedded credentials is required for Gradle.")
    gradle_directory = Path(os.environ["GRADLE_USER_HOME"])
    gradle_directory.mkdir(parents=True, exist_ok=True)
    properties = gradle_directory / "gradle.properties"
    start, end = "# BEGIN NADA CLOUD PROXY", "# END NADA CLOUD PROXY"
    existing = properties.read_text() if properties.exists() else ""
    if start in existing and end in existing:
        existing = existing[:existing.index(start)] + existing[existing.index(end) + len(end):]
    port = proxy.port or (443 if proxy.scheme == "https" else 80)
    settings = [start]
    for protocol in ("https", "http"):
        settings.extend([
            f"systemProp.{protocol}.proxyHost={proxy.hostname}",
            f"systemProp.{protocol}.proxyPort={port}",
            f"systemProp.{protocol}.nonProxyHosts=localhost|127.*|[::1]",
        ])
    # The cloud image's managed Java trust store includes its injected proxy CA.
    # Keep standard PKIX validation and public roots when using a downloaded JDK.
    trust_store = Path('/etc/ssl/certs/java/cacerts')
    if trust_store.is_file():
        settings.append(f'systemProp.javax.net.ssl.trustStore={trust_store}')
    settings.append(end)
    properties.write_text(existing.rstrip() + "\n" + "\n".join(settings) + "\n")
    if '--java-options' in sys.argv:
        print(' '.join(shlex.quote('-D' + item.removeprefix('systemProp.'))
                       for item in settings if item.startswith('systemProp.')))
