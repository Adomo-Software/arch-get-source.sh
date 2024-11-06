# https://wiki.archlinux.org/title/Arch_build_system

# REQUIREMENT: devtools

# TODO: handle updating source code maybe?

USAGE="Usage: `basename $0` PACKAGE_NAME"
if [ $# -gt 1 ]; then
    echo -e "Too many arguments\n$USAGE" >&2
    exit 1
elif [ -z "$1" ]; then
    echo -e "Not enough arguments\n$USAGE" >&2
    exit 1
fi

SRCDIR=$HOME/.pkg-src

mkdir -p $SRCDIR/pkgbuilds
mkdir -p $SRCDIR/sources

BORING=1

if [ ! -d "$SRCDIR/pkgbuilds/$1" ]; then
		pacman -Sql | grep -q "^$1$" || { echo "Error: package $1 doesn't exist"; exit 1; }
		( cd "$SRCDIR/pkgbuilds/";
			pkgctl repo clone --protocol https 2>&1 $1 ) || exit 1
		BORING=0
fi

if [ ! -d "$SRCDIR/sources/$1" ]; then
		. $SRCDIR/pkgbuilds/$1/PKGBUILD
		protocol=$(echo $source | cut -d':' -f1)

		if echo $protocol | grep -q "git"; then
				repo_url=$(echo "$source" | sed -e 's|^git+https://|https://|' -e 's|#commit=.*||')
				git clone $repo_url $SRCDIR/sources/$1 >&2
				( cd $SRCDIR/sources/$1; git checkout $commit )
				echo "$repo_url $commit"
				echo $SRCDIR/sources/$1
		elif echo $protocol | grep -q "http"; then
				wget -P $SRCDIR/sources/$1 $source
				unzipme=$(ls $SRCDIR/sources/$1/*.tar.*)
				if [ -n "$unzipme" ]; then
						case "$unzipme" in
								*.tar.gz)   tarflag="-xzvf" ;;
								*.tar.bz2)  tarflag="-xjvf" ;;
								*.tar.xz)   tarflag="-xJvf" ;;
								*.tar)      tarflag="-xvf" ;;
								*)          echo "Unsupported tar format: $unzipme" >&2; exit 1 ;;
						esac
						tar $tarflag "$unzipme" -C $SRCDIR/sources/$1 >&2
						rm $unzipme
						if [ $(find $SRCDIR/sources/$1 -mindepth 1 -maxdepth 1 -type d | wc -l) -eq 1 ]; then
								single=$(find $SRCDIR/sources/$1 -mindepth 1 -maxdepth 1 -type d)
								mv $single /tmp
								rmdir $SRCDIR/sources/$1
								mv /tmp/$(basename $single) $SRCDIR/sources/$1
						fi
				fi		else
				echo "Error: This protocol is unsupported" >&2
				echo "$protocol" >&2
				exit 1
		fi
		echo -e "\nDone, take a look:" >&2
		echo $SRCDIR/sources/$1
		BORING=0
fi

if [ $BORING -eq 1 ]; then
		echo "Info: source code is already downloaded" >&2
		echo $SRCDIR/sources/$1
fi
