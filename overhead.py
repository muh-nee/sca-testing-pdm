import pandas
import matplotlib.pyplot as plt
import re
from pathlib import Path


def handle(data, metric, reverse):
    df = pandas.DataFrame(data)
    means = df.mean()
    errors = df.std()

    names = sorted(df.columns, key=lambda n:means[n], reverse=reverse)
    basename = names[0]
    base = means[basename]

    print(metric)
    for name in names:
        val = means[name]
        if val == base:
            extra = ""
        else:
            diff = ((val - base) / base) * 100.
            direction = "higher"

            if reverse:
                diff = -1 * diff
                direction = "lower"

            extra = f" ({diff:5.2f}% {direction} than {basename})"

        error = errors[name]
        errorpct = (error / val) * 100.
        print(f"{name:25s}{val:10.2f} ± {error:6.2f} (±{errorpct:5.2f}%){extra}")

    del means["plain-usm"]
    del means["plain-npm"]
    del errors["plain-usm"]
    del errors["plain-npm"]

    plt.errorbar(means.index, means, yerr=errors, fmt="o", linewidth=2, capsize=6)
    plt.ylabel(metric)
    plt.savefig(f"overhead-{metric}.svg")
    plt.close()

if __name__ == '__main__':
    rps = {}
    time = {}
    rpspat = re.compile("Requests per second:.*?([0-9.]+)")
    for f in Path("logs").glob("plain-*.txt"):
        name = f.stem
        rps[name] = []
        time[name] = []
        for line in f.read_text().splitlines():
            m = rpspat.match(line)
            if m:
                raw = m.groups()[0]
                rps[name].append(float(raw))

    plt.style.use('ggplot')

    handle(rps, "rps", reverse=True)
