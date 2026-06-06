package com.apache.fastandroid.home

import android.view.View
import android.view.ViewTreeObserver
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView
import com.apache.fastandroid.R
import com.apache.fastandroid.databinding.ArticleItemBinding
import com.apache.fastandroid.network.model.Article
import com.chad.library.adapter.base.BaseQuickAdapter
import com.chad.library.adapter.base.module.LoadMoreModule
import com.chad.library.adapter.base.viewholder.BaseDataBindingHolder
import com.tesla.framework.common.util.CommonUtil
import com.tesla.framework.common.util.LaunchTimer
import com.tesla.framework.common.util.buildSpannableString
import com.tesla.framework.kt.getColor
import com.tesla.framework.kt.isNotNullOrEmpty

/**
 * Created by Jerry on 2021/7/1.
 * 警告：将 ViewModel 传入 RecyclerView 适配器是一种不妥的做法，因为它会将适配器与 ViewModel 类紧密耦合。
 */
class ArticleAdapter(
    data: List<Article>,
    val listener: (View, Int) -> Unit = { viwe, position -> },
) :
    BaseQuickAdapter<Article, BaseDataBindingHolder<ArticleItemBinding>>(
        R.layout.article_item,
        data.toMutableList()
    ),
    LoadMoreModule {

    init {
        setHasStableIds(true)
    }

    override fun getItemId(position: Int): Long {
        if (position !in data.indices) {
            return RecyclerView.NO_ID
        }

        val article = data[position]
        if (article.id != 0) {
            return article.id.toLong()
        }

        return "${article.link}_${article.title}_${article.niceDate}".hashCode().toLong()
    }


    private var mHasRecord = false
    override fun convert(holder: BaseDataBindingHolder<ArticleItemBinding>, article: Article) {
        // Feed 流第一个 item 作为用户第一次看见
        if (holder.bindingAdapterPosition == 0 && !mHasRecord){
            mHasRecord = true
            holder.itemView.viewTreeObserver.addOnPreDrawListener(object :ViewTreeObserver.OnPreDrawListener{
                override fun onPreDraw(): Boolean {
                    LaunchTimer.endRecord("Feed Show")
                    holder.itemView.viewTreeObserver.removeOnPreDrawListener(this)

                    return false
                }

            })

        }
        holder
            .setText(R.id.item_article_title, handleTitle(article))
            .setText(R.id.item_article_date, article.niceDate)
            .setText(R.id.item_article_type, handleCategory(article))
            .setImageResource(R.id.item_list_collect, isCollect(article))


        val authorView = holder.getView<TextView>(R.id.item_article_author)
        authorView.buildSpannableString {
            if (article.top) {
                append("置顶  ") {
                    setColor(R.color.holo_red_light.getColor(context))
                }
            }
            if (article.fresh) {
                append("新  ") {
                    setColor(R.color.holo_red_light.getColor(context))
                }
            }
            append(handleAuthor(article))
        }

        // 作者点击通过 listener 回传给 Fragment 处理，避免把回调耦合进实体
        authorView.setOnClickListener {
            listener(it, holder.bindingAdapterPosition)
        }
    }

    private fun handleTitle(article: Article?): String {
        if (article == null) return ""
        // 优先用转换阶段预解析好的标题，缺省时再兜底解析一次
        return article.displayTitle.ifEmpty { CommonUtil.fromHtml(article.title).toString() }
    }

    private fun handleAuthor(article: Article): String {
        return when {
            // 官方/原创文章优先展示作者
            article.author.isNotNullOrEmpty() -> "作者" + article.author
            // 广场分享文章展示分享人
            article.shareUser.isNotNullOrEmpty() -> "分享人" + article.shareUser
            else -> "匿名用户"
        }
    }

    private fun handleCategory(article: Article): String {
        val superName = article.superChapterName
        val chapterName = article.chapterName
        return when {
            superName.isNullOrEmpty() && chapterName.isNullOrEmpty() -> ""
            superName.isNullOrEmpty() -> chapterName.orEmpty()
            chapterName.isNullOrEmpty() -> superName
            else -> "$superName·$chapterName"
        }
    }

    private fun isCollect(article: Article): Int {
        return if (article.collect) R.drawable.collect_selector_icon else R.drawable.uncollect_selector_icon
    }


}
