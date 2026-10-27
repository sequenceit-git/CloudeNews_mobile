package com.tencent.cloud.tuikit.flutter.tuichatkit.videorecorder.view.recordview.beauty;
import android.widget.BaseAdapter;

public abstract class BeautyScrollViewAdapter extends BaseAdapter {

    protected int mSelectPosition = -1;

    public int getSelectPosition() {
        return mSelectPosition;
    }

    public void setSelectPosition(int position) {
        mSelectPosition = position;
    }
}
