package admin

import (
    "html/template"
    "net/http"
    "strings"

    "database/sql"
)

// 这里用之前在 README 里定义过的 ViewModel

type AdminPageData struct {
    SearchSN      string
    CurrentStatus *CPEStatusView
    History       []CPEHistoryRow
    Metrics       AdminMetricsBlock
    KibanaLink    string
    ErrorMessage  string
}

type CPEStatusView struct {
    SN              string
    WANIP           string
    SWVersion       string
    CPUPct          int
    MemPct          int
    LastHeartbeatAt string // 为方便渲染，转成 string
}

type CPEHistoryRow struct {
    HeartbeatAt string
    WANIP       string
    CPUPct      int
    MemPct      int
}

type AdminMetricsBlock struct {
    HeartbeatChartURL string
    CPUChartURL       string
    MemChartURL       string
}

// 可以在 main 里注入进来
type AdminHandler struct {
    DB       *sql.DB
    Template *template.Template
}

func NewAdminHandler(db *sql.DB, tpl *template.Template) *AdminHandler {
    return &AdminHandler{
        DB:       db,
        Template: tpl,
    }
}

func (h *AdminHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
    ctx := r.Context()

    pageData := AdminPageData{
        SearchSN:      "",
        CurrentStatus: nil,
        History:       []CPEHistoryRow{},
        Metrics:       AdminMetricsBlock{}, // 暂时空
        KibanaLink:    "",
        ErrorMessage:  "",
    }

    sn := strings.TrimSpace(r.URL.Query().Get("sn"))
    if sn == "" {
        // 没传 SN，只展示搜索框
        if err := h.Template.ExecuteTemplate(w, "admin.html", pageData); err != nil {
            http.Error(w, err.Error(), http.StatusInternalServerError)
        }
        return
    }

    pageData.SearchSN = sn

    // 1) 查当前状态
    currentRow, err := GetCurrentStatusBySN(ctx, h.DB, sn)
    if err != nil {
        http.Error(w, "database error", http.StatusInternalServerError)
        return
    }

    if currentRow == nil {
        // 没有找到当前状态
        pageData.ErrorMessage = "SN not found"

        // 也可以查一下历史，可能历史有数据但 current 没有
        historyRows, err := GetHistoryBySN(ctx, h.DB, sn, 20)
        if err == nil {
            pageData.History = mapHistoryRows(historyRows)
        }

        if err := h.Template.ExecuteTemplate(w, "admin.html", pageData); err != nil {
            http.Error(w, err.Error(), http.StatusInternalServerError)
        }
        return
    }

    // 映射 currentStatus
    pageData.CurrentStatus = &CPEStatusView{
        SN:              currentRow.SN,
        WANIP:           currentRow.WANIP,
        SWVersion:       currentRow.SWVersion,
        CPUPct:          currentRow.CPUPct,
        MemPct:          currentRow.MemPct,
        LastHeartbeatAt: currentRow.LastHeartbeatAt.Format("2006-01-02 15:04:05"),
    }

    // 2) 查历史
    historyRows, err := GetHistoryBySN(ctx, h.DB, sn, 20)
    if err != nil {
        http.Error(w, "database error", http.StatusInternalServerError)
        return
    }
    pageData.History = mapHistoryRows(historyRows)

    // 3) metrics & kibana_link 暂时先空，后面子任务填
    // pageData.Metrics = ...
    // pageData.KibanaLink = ...

    if err := h.Template.ExecuteTemplate(w, "admin.html", pageData); err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }
}

func mapHistoryRows(rows []cpeHistoryRow) []CPEHistoryRow {
    result := make([]CPEHistoryRow, 0, len(rows))
    for _, r := range rows {
        result = append(result, CPEHistoryRow{
            HeartbeatAt: r.HeartbeatAt.Format("2006-01-02 15:04:05"),
            WANIP:       r.WANIP,
            CPUPct:      r.CPUPct,
            MemPct:      r.MemPct,
        })
    }
    return result
}

