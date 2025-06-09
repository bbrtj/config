synclient FingerHigh=40
synclient MaxTapTime=250
synclient MaxTapMove=20
synclient MaxSpeed=2
synclient TapButton2=0
synclient TapButton3=2
synclient HorizTwoFingerScroll=1
synclient PalmDetect=1
synclient PalmMinWidth=3
synclient PalmMinZ=30
synclient AreaLeftEdge=200
synclient AreaRightEdge=$(($(synclient | perl -ne 'print m{\bRightEdge\s+=\s+(\d+)}')-200))
synclient AreaTopEdge=100

export DMENU_PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin"

