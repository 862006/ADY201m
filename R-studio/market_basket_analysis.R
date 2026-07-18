# ============================================================
# MARKET BASKET ANALYSIS — INSTACART (ADY201)
# ============================================================

library(arules)
library(arulesViz)
library(stringr)
library(rstudioapi)

# ============================================================
# TỰ ĐỘNG XÁC ĐỊNH VỊ TRÍ FILE CODE CHẠY ĐỂ LẤY DATA
# ============================================================

script_path <- rstudioapi::getActiveDocumentContext()$path

if (script_path == "") {
  stop("Không lấy được đường dẫn file code. Hãy đảm bảo bạn đang chạy trong RStudio và file .R này đang mở ở tab hiện tại (đã save, không phải 'Untitled').")
}

script_dir   <- dirname(script_path)
project_root <- dirname(script_dir)

cat("Script dir:", script_dir, "\n")
cat("Project root:", project_root, "\n")

data_path   <- file.path(project_root, "Data", "transactions.csv")
output_path <- file.path(project_root, "R-studio", "rules_output.csv")

cat("Đường dẫn data:", data_path, "\n")
cat("File có tồn tại không:", file.exists(data_path), "\n")

if (!file.exists(data_path)) {
  stop("Không tìm thấy file transactions.csv tại đường dẫn trên. Kiểm tra lại tên thư mục 'Data' và tên file có đúng chính xác (phân biệt hoa/thường) không.")
}

# ============================================================
# ĐỌC FILE
# ============================================================

raw_lines <- readLines(data_path, encoding = "UTF-8")
cat("Total lines read:", length(raw_lines), "\n")

# ============================================================
# PARSE TỪNG DÒNG
# Cấu trúc gốc: "ID,""SP1,SP2,SP3""";;
# ============================================================

parse_line <- function(line) {
  line <- str_trim(line)
  matched <- str_match(line, '^"\\d+,""(.+)""";*$')
  if (is.na(matched[1, 2])) return(NULL)
  products <- str_split(matched[1, 2], ",")[[1]]
  products <- str_trim(products)
  products <- products[products != ""]
  return(products)
}

parsed <- lapply(raw_lines, parse_line)
parsed <- Filter(Negate(is.null), parsed)
cat("Successfully parsed transactions:", length(parsed), "\n")

# ============================================================
# CHUYỂN SANG OBJECT transactions
# ============================================================

transactions <- as(parsed, "transactions")
summary(transactions)

# ============================================================
# LẤY MẪU
# ============================================================

set.seed(42)
sample_size <- 90000
total <- length(transactions)

if (total > sample_size) {
  idx <- sample(1:total, sample_size)
  transactions <- transactions[idx]
}

cat("Transactions after sampling:", length(transactions), "\n")

# ============================================================
# KHÁM PHÁ DỮ LIỆU
# ============================================================

itemFrequencyPlot(transactions,
                  topN = 20,
                  type = "relative",
                  main = "Top 20 Most Popular Products",
                  col  = "steelblue",
                  ylab = "Occurrence Rate")

hist(size(transactions),
     breaks = 30,
     main   = "Distribution of Products per Transaction",
     xlab   = "Number of Products",
     col    = "lightblue")

# ============================================================
# CHẠY THUẬT TOÁN APRIORI
# ============================================================

rules <- apriori(
  transactions,
  parameter = list(
    support    = 0.001,
    confidence = 0.3,
    minlen     = 2,
    maxlen     = 4
  )
)

cat("Total rules:", length(rules), "\n")
summary(rules)

# ============================================================
# LỌC VÀ SẮP XẾP
# ============================================================

rules_strong <- subset(rules, lift > 1.5)
rules_sorted <- sort(rules_strong, by = "lift", decreasing = TRUE)

cat("Strong rules (lift > 1.5):", length(rules_strong), "\n")
inspect(head(rules_sorted, 5))

# ============================================================
# TRỰC QUAN HÓA
# ============================================================

plot(rules_strong,
     method  = "scatterplot",
     measure = c("support", "confidence"),
     shading = "lift",
     control = list(col = "black"),
     main    = "Association Rule Distribution")

top15 <- head(rules_sorted, 15)
plot(top15,
     method = "graph",
     engine = "htmlwidget",
     main   = "Product Network Frequently Purchased Together")

inspectDT(rules_sorted)

# ============================================================
# BƯỚC 9 — XUẤT CHO POWER BI
# ============================================================

rules_df <- as(rules_sorted, "data.frame")

rules_df$lhs <- str_extract(rules_df$rules, "^\\{.*?\\}")
rules_df$rhs <- str_extract(rules_df$rules, "\\{[^\\{]*\\}$")

rules_df$support    <- round(rules_df$support, 4)
rules_df$confidence <- round(rules_df$confidence, 4)
rules_df$lift       <- round(rules_df$lift, 4)

rules_df <- rules_df[, c("lhs", "rhs", "support", "confidence", "lift", "count")]

write.csv(rules_df, output_path, row.names = FALSE)

cat("Exported", nrow(rules_df), "rules to:", output_path, "\n")

# ============================================================
# BƯỚC 10 — KIỂM TRA FILE OUTPUT
# ============================================================

check <- read.csv(output_path)
cat("Number of rows:", nrow(check), "\n")
cat("Columns:", paste(colnames(check), collapse = ", "), "\n")
print(head(check, 5))