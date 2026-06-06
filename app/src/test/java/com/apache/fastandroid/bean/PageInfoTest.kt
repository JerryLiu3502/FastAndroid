package com.apache.fastandroid.bean

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * [PageInfo] 的纯 JVM 单元测试。
 * 覆盖初始状态、翻页自增、重置，以及 isFirstPage 的各分支与边界。
 */
class PageInfoTest {

    @Test
    fun initialState_pageIsZero_andIsFirstPage() {
        val pageInfo = PageInfo()

        assertEquals(0, pageInfo.page)
        assertTrue(pageInfo.isFirstPage())
    }

    @Test
    fun nextPage_incrementsPageByOne() {
        val pageInfo = PageInfo()

        pageInfo.nextPage()

        assertEquals(1, pageInfo.page)
    }

    @Test
    fun nextPage_calledMultipleTimes_accumulates() {
        val pageInfo = PageInfo()

        repeat(3) { pageInfo.nextPage() }

        assertEquals(3, pageInfo.page)
    }

    @Test
    fun isFirstPage_afterNextPage_returnsFalse() {
        val pageInfo = PageInfo()

        pageInfo.nextPage()

        assertFalse(pageInfo.isFirstPage())
    }

    @Test
    fun reset_afterAdvancing_returnsToFirstPage() {
        val pageInfo = PageInfo()
        repeat(5) { pageInfo.nextPage() }

        pageInfo.reset()

        assertEquals(0, pageInfo.page)
        assertTrue(pageInfo.isFirstPage())
    }

    @Test
    fun reset_onFreshInstance_isIdempotent() {
        val pageInfo = PageInfo()

        pageInfo.reset()

        assertEquals(0, pageInfo.page)
        assertTrue(pageInfo.isFirstPage())
    }

    @Test
    fun resetThenNextPage_startsFromOneAgain() {
        val pageInfo = PageInfo()
        repeat(2) { pageInfo.nextPage() }
        pageInfo.reset()

        pageInfo.nextPage()

        assertEquals(1, pageInfo.page)
        assertFalse(pageInfo.isFirstPage())
    }
}
