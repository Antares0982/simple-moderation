# simple-moderation

零第三方依赖的 Python 图片/文本 moderation 工具，提供 HTTP server 和 CLI。
使用 DeepSeek `deepseek-flash`，输出 `self-harm`、`sexual`、`violence` 三类布尔值。

分类含义参考 [OpenAI Moderation](https://developers.openai.com/api/docs/guides/moderation)：

- `self-harm`：自伤描写、鼓励、意图或指导，包括自杀、自残、进食障碍行为。
- `sexual`：色情内容或性服务推广，包括涉及未成年人的性内容；排除非色情的性教育和性健康内容。
- `violence`：死亡、暴力或身体伤害的描写，包括血腥细节。

多个类别可以同时命中，子类统一归入主类。这里使用通用模型进行分类，不等同于 OpenAI 的 moderation 模型，也不提供未经校准的置信度。

## CLI

使用 Python 3.10+，无需安装依赖：

```bash
export DEEPSEEK_API_KEY='your-api-key'
python3 simple_moderation.py check --text '今天天气不错'
python3 simple_moderation.py check --image ./photo.png
python3 simple_moderation.py check --image https://example.com/photo.png
cat article.txt | python3 simple_moderation.py check --text -
python3 simple_moderation.py check --text '图片说明' --image ./photo.png
```

也可以通过 UTF-8 文件提供密钥：

```bash
python3 simple_moderation.py check --text '待检测文本' \
  --api-key-file ~/.config/deepseek/key
```

密钥文件优先于环境变量，去除首尾空白；显式指定的文件不可读或为空时直接报错。请将密钥文件放在仓库外。

stdout 只输出结果 JSON，错误写入 stderr。退出码：`0` 未命中、`1` 命中、`2` 输入或检测失败。

## HTTP server

```bash
export DEEPSEEK_API_KEY='your-api-key'
python3 simple_moderation.py serve
# 修改监听地址或端口：
python3 simple_moderation.py serve --host 127.0.0.1 --port 8080
```

默认监听 `127.0.0.1:8000`，密钥只读取服务进程环境变量。服务不提供客户端鉴权；默认用于本机调用，若要对外提供服务，应由反向代理负责鉴权、TLS 和并发限制。

```bash
curl http://127.0.0.1:8000/moderate \
  -H 'Content-Type: application/json' \
  -d '{"text":"今天天气不错"}'

curl http://127.0.0.1:8000/moderate \
  -H 'Content-Type: application/json' \
  -d '{"text":"图片说明","image":"https://example.com/photo.png"}'
```

`POST /moderate` 只接受 `text` 和 `image` 字段，至少提供一个非空字符串。同时提供时联合判断，返回一个结果。`image` 接受 HTTP(S) URL 或 `data:image/png;base64,...` 等 data URL；HTTP 接口不接受本地文件路径。请求必须带 `Content-Length`，不支持分块上传。

HTTP 和 CLI 的结果格式一致：

```json
{
  "flagged": false,
  "categories": {"self-harm": false, "sexual": false, "violence": false}
}
```

`flagged` 为三个类别的逻辑或。HTTP 检测成功均返回 200；输入错误 400、超限 413、上游失败或结果无效 502、上游超时 504。错误格式为 `{"error":"..."}`，不包含待检测内容、密钥或上游响应正文。空响应、拒答、截断和错误分类格式不会被当作“未命中”。

## 图片与调用限制

- 支持 JPEG、PNG、WebP、GIF。本地文件按文件头识别类型，不依赖扩展名；完整图片解码由 DeepSeek 完成。
- 单张内嵌图片最多 32 MiB；HTTP 请求及编码后的 DeepSeek 请求最多 48 MiB，后者包含提示词等开销。
- 图片 URL 最长 8192 字符，由 DeepSeek 下载，需能被其访问；远程图片的尺寸和下载限制由上游校验。详见 [DeepSeek Vision](https://api-docs.deepseek.com/guides/vision/)。
- 每次检测发送一次请求，网络操作超时为 60 秒；不自动重试、不批量处理、不缓存或存储输入。
- 采用 [JSON 输出](https://api-docs.deepseek.com/guides/json_mode/)，开启思考模式并设置 `reasoning_effort=high`；不传 `max_tokens`，使用上游默认输出上限，也不传思考模式下无效的 `temperature`。模型判定仍可能有误报或漏报，应使用实际业务样本验证效果。

## 检查

```bash
python3 test_moderation.py
```

离线检查启动本机模拟上游和 HTTP 服务，无需密钥、不访问 DeepSeek。覆盖 HTTP、CLI、stdin、本地图片、密钥优先级、类别组合、非法输入、上游错误和超时；运行环境需允许监听回环端口。

显式调用真实 API 做冒烟检查：

```bash
DEEPSEEK_API_KEY='your-api-key' python3 test_moderation.py --live
```

这会在离线检查后发起 12 次计费请求，检查中英文正反例、提示注入样例和一张无害图片。离线检查不能证明模型准确率；无害图片只验证图片调用链路，三类图片的识别效果仍需使用合法取得的标注图片验证。
