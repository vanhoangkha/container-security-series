# Tám năm xây hạ tầng tại Atlassian — rồi bị sa thải

> Tổng hợp từ video gốc "I was laid off by Atlassian" của Vasilios Syrakis (đăng tháng 5/2026), các bài phân tích trên Medium, Financial Express, IT Chronicles Substack, và mã nguồn mở Sovereign trên GitHub.

---

## Bối cảnh

Ngày 11 tháng 3 năm 2026, CEO Atlassian Mike Cannon-Brookes thông báo cắt giảm khoảng 1.600 nhân sự — tương đương 10% lực lượng lao động toàn cầu. Lý do chính thức: tái cấu trúc để đầu tư mạnh hơn vào AI và mảng enterprise sales. Chi phí tái cấu trúc ước tính 225–236 triệu USD. CTO Rajeev Rajan cũng rời đi cùng thời điểm.

Một ngày sau, ngày 12 tháng 3, Vasilios Syrakis — kỹ sư hạ tầng đã làm việc gần tám năm tại Atlassian — nhận thông báo sa thải.

Thay vì đăng một bài than phiền, anh ra một video dài 38 phút trên YouTube kể lại toàn bộ những gì đã xây dựng. Video nhanh chóng được cộng đồng kỹ thuật gọi là "mỏ vàng kiến thức về platform engineering."

---

## Người kể chuyện

Vasilios Syrakis (GitHub: **cetanu**) — Pythonista từ 2013, làm việc trong team Network Edge tại Atlassian. Anh xây dựng hạ tầng load balancing tự phục vụ phục vụ các sản phẩm Jira, Confluence, Bitbucket và nhiều microservices nội bộ.

---

## Phỏng vấn và lời hứa

Quy trình phỏng vấn gồm bốn vòng:

1. **Coding quiz** trên HackerRank — đạt điểm tuyệt đối.
2. **Kỹ thuật** — được đưa một white paper của Cloudflare về custom domains, đọc 10 phút rồi thảo luận. Tiếp theo là câu hỏi về microservices, containers, kiến trúc.
3. **Troubleshooting** — phải tự đặt câu hỏi để gỡ một sự cố thật (denial of service do lỗi ứng dụng). Rồi hỏi về DNS định tuyến theo độ trễ của Route 53.
4. **Values** — Syrakis hỏi ngược: "12 tháng nữa, tôi phải làm được gì thì anh mới thấy quyết định tuyển tôi là đúng?"

Câu trả lời: xây một ứng dụng load balancing tự phục vụ cho developer nội bộ — kiểu như Application Load Balancer của AWS nhưng dùng nội bộ.

---

## Năm đầu: Open Service Broker

Nhiệm vụ đầu tiên: xây đúng cái đã hứa. Kiến trúc:

```
Developer gọi API
       |
       v
+------------------+
|  Web Server      |  (ban đầu OpenAPI generator -> Flask -> cuối cùng FastAPI)
+--------+---------+
         |
         v
+------------------+
|  SQS Queue       |  (hàng đợi tác vụ)
+--------+---------+
         |
         v
+------------------+
|  Worker          |  (nhặt tác vụ, thực thi)
|  - Tạo DNS      |
|  - Dựng CDN     |
|  - Gọi cloud API|
+--------+---------+
         |
         v
+------------------+
|  DynamoDB        |  (lưu kết quả)
+------------------+
         ^
         |
   Client poll liên tục cho đến khi hoàn tất
```

Pattern này — API nhận request, đẩy vào queue, worker xử lý bất đồng bộ, client poll kết quả — là pattern chuẩn cho provisioning platform. Đơn giản nhưng scale tốt.

---

## Envoy và Sovereign: Thay load balancer bằng proxy mã nguồn mở

Ý tưởng cốt lõi: thay thế load balancer enterprise đắt đỏ (có phí bản quyền) bằng Envoy — proxy cloud-native, mã nguồn mở.

Điểm mạnh của Envoy: có API cấu hình động (XDS protocol). Nghĩa là proxy chạy thường trực, khi developer cần thay đổi cấu hình, thay đổi "chảy" tới proxy mà không cần khởi động lại.

Để quản lý cấu hình động này, Syrakis xây **Sovereign** — một control plane cho Envoy:

```
+------------------+       +------------------+
|  Templates       |       |  Context         |
|  (cluster,       |       |  (từ DynamoDB,   |
|   route,         | +---> |   S3 bucket,     |
|   listener)      |       |   HTTP endpoint) |
+--------+---------+       +--------+---------+
         |                          |
         +------------+-------------+
                      |
                      v
         +------------------+
         |  SOVEREIGN       |
         |  Control Plane   |
         |  (render config) |
         +--------+---------+
                  |
                  | XDS protocol
                  v
    +------+------+------+------+
    |Envoy |Envoy |Envoy | ...  |  (~2000 proxies, ~13 regions)
    +------+------+------+------+
```

Sovereign nhận templates và context, render ra cấu hình Envoy. Khi context thay đổi (ví dụ developer thêm route mới), cấu hình tự động cập nhật tới tất cả proxy liên quan.

**Sovereign là open source:** github.com/cetanu/sovereign — và có documentation chính thức trên developer.atlassian.com/platform/sovereign.

---

## Hạ tầng: Từ AMI tới 2000 proxy

Proxy được cấp phát bằng CloudFormation (IaC của AWS):

- VPC, subnet, internet gateway, security group
- Auto Scaling Group → sinh EC2 instances
- NLB (Network Load Balancer tầng 4)
- ACM (certificate) + Route 53 (DNS)

AMI (image chuẩn cho proxy) được build riêng:

1. **Packer** dựng EC2 tạm trong tài khoản dev
2. **SaltStack** cài và cấu hình: Envoy, logging/tracing agents, hardening, tinh chỉnh network
3. Snapshot thành AMI
4. Khi khởi chạy, CloudFormation truyền tham số (secrets, keys), proxy tự lấy tài nguyên và bắt đầu nhận traffic

Quy mô cuối cùng: khoảng 2.000 proxy trên 13 AWS regions.

---

## Mở rộng: Biến nó thành con đường mặc định

Giai đoạn tiếp theo: kéo toàn bộ sản phẩm lớn (Jira, Confluence, Bitbucket, Status Page) và microservices nội bộ lên nền tảng edge này.

Chiến lược cưỡng chế:
- Trước đây: platform cấp load balancing cơ bản, dịch vụ có thể vô tình lộ ra public không được bảo vệ.
- Sau: muốn expose ra ngoài phải đi qua hạ tầng edge trung tâm và **khai báo rõ ràng ý định public**.

Đây là mô hình "golden path" — con đường mặc định an toàn. Developer không bị cấm, nhưng cách dễ nhất (và duy nhất) để ra internet là qua platform đã hardened sẵn.

---

## Edge compute: Xử lý vấn đề trước khi chạm backend

Khi đã có cấu hình động tại edge, cơ hội mở ra: tập trung hoá các mối quan tâm chung ngay tại proxy.

```
Khách hàng -> NLB -> Envoy Proxy -> Backend
                        |
                        | Xử lý tại đây:
                        | - Chống DDoS (CloudFront)
                        | - Access logs (Envoy HTTP filter)
                        | - Authentication (sidecar Rust)
                        | - Authorization (sidecar, team khác)
                        | - Rate limiting (sidecar, team khác)
                        |
                        v
                   Backend chỉ nhận traffic đã clean
```

Lợi ích: hàng nghìn team developer không phải tự implement auth, rate limiting, logging cho dịch vụ của mình. Một lần làm tại edge, phục vụ toàn bộ tổ chức.

Chi tiết kỹ thuật:
- Chống DDoS: nhờ CloudFront (do đồng nghiệp xây)
- Access logs: network filter trong Envoy HTTP connection manager, cấu hình động qua template
- Auth/Authz/Rate limiting: mô hình sidecar — container chạy cục bộ cạnh proxy, nhận cấu hình động
- Authentication sidecar: Syrakis viết bằng Rust

---

## Bài học không nằm trong code

### Ngoại giao và xung đột

> "Thứ tôi trưởng thành nhiều nhất lại là ngoại giao: tránh và hoá giải xung đột, thuyết phục, đề xuất ý tưởng."

Tám năm gặp đủ kiểu quản lý và đồng nghiệp. Xung đột xảy ra — kể cả với người vẫn tôn trọng. Đôi khi đơn giản là tính cách không hợp. Cách duy nhất: giữ đủ tự nhận thức và hiểu tâm lý người kia để lường trước va chạm.

### Gánh nặng bảo trì

> "Xây một thứ thì dễ. Thay đổi nó, và giữ cho nó vẫn dễ thay đổi theo thời gian, mới khó."

Khái niệm **code churn** — vùng code cứ bị sửa đi sửa lại. Đó là dấu hiệu sớm cho thấy phần đó sẽ ngày càng phức tạp và cần tái cấu trúc trước khi thành đống hỗn độn.

Gánh nặng bảo trì không lộ ra ở giai đoạn đầu:
- Chưa đủ traffic, chưa đủ thay đổi, chưa đủ thời gian
- Phải onboard người mới, viết tài liệu, đào tạo on-call
- Người đến rồi đi, người mới muốn cải tiến, vòng lặp onboarding không dừng

Syrakis đặt câu hỏi thú vị: ứng dụng được "vibe-code" bằng AI rồi sẽ gánh bảo trì thế nào, khi chính người tạo cũng không hiểu thứ mình đã tạo?

### Mentoring

Năm cuối, Syrakis kèm một thực tập sinh đạt mức đánh giá cao nhất. Nhưng anh thừa nhận mentoring khó:

> "Tôi không muốn đưa thẳng đáp án, nhưng cũng không muốn bạn ấy bí đến mức nản. Tôi không chắc mình đã chạm đúng điểm cân bằng đó."

Anh tự tin hơn ở việc **huấn luyện đồng nghiệp** — cùng ngồi gỡ vấn đề, biến chủ đề khó thành dễ hiểu. Đó là "cơm áo" suốt nửa sau quãng thời gian ở Atlassian.

---

## Kiến trúc tổng quan (toàn bộ hệ thống)

```
+-------------------------------------------------------------------+
|                          DEVELOPER                                 |
|  "Tôi muốn dịch vụ ra Internet, có routing nâng cao"             |
+-----------------------------------+-------------------------------+
                                    |
                                    | Gọi API
                                    v
+-------------------------------------------------------------------+
|  OPEN SERVICE BROKER (FastAPI)                                     |
|  Nhận yêu cầu -> SQS -> Worker provision -> DynamoDB              |
+-----------------------------------+-------------------------------+
                                    |
                                    | Ghi context
                                    v
+-------------------------------------------------------------------+
|  SOVEREIGN (Control Plane)                                         |
|  Template + Context -> Render Envoy config -> XDS push            |
+-----------------------------------+-------------------------------+
                                    |
                                    | XDS protocol (gRPC)
                                    v
+-------------------------------------------------------------------+
|  ENVOY PROXY FLEET (~2000 proxies, 13 regions)                    |
|  + Sidecars: Auth (Rust), Authz, Rate Limiting                    |
|  Provisioned bằng: CloudFormation + Packer + SaltStack            |
+-------------------------------------------------------------------+
                                    |
                                    | Cleaned traffic
                                    v
+-------------------------------------------------------------------+
|  BACKEND SERVICES                                                  |
|  Jira, Confluence, Bitbucket, Status Page, microservices           |
+-------------------------------------------------------------------+
```

---

## Những điểm đáng học cho platform engineer

| Bài Học | Chi Tiết |
|---------|----------|
| Hứa trong phỏng vấn, rồi deliver | Syrakis hỏi "12 tháng nữa tôi phải làm gì?" rồi xây đúng cái đó |
| Pattern provisioning đơn giản scale tốt | API -> Queue -> Worker -> Store + Poll. Không phức tạp hoá. |
| Cấu hình động là chìa khoá | Proxy chạy thường trực, config "chảy" tới — không restart |
| Golden path qua cưỡng chế nhẹ | Muốn ra internet? Chỉ có một cách: qua edge platform |
| Edge compute tiết kiệm toàn tổ chức | Auth/logging/rate-limit làm 1 lần tại edge, 1000 team được lợi |
| Code churn là mùi kiến trúc | Chỗ nào sửa đi sửa lại = sẽ thành đống hỗn độn |
| Soft skills không kém technical | Ngoại giao, conflict resolution, mentoring = trưởng thành nhiều nhất |
| Open source portfolio có giá trị | Sovereign là bằng chứng công khai của 8 năm làm việc |

---

## Phản ứng từ cộng đồng

- Financial Express: "Laid off engineer shares 38-minute 'what I built' video instead of a rant"
- IT Chronicles Substack: "A gold mine of platform engineering wisdom"
- Medium/GitConnected: "He responded by giving away everything he knew"
- Social Storytellers: "The blueprint still belongs to the worker"

Video nhận được sự tôn trọng lớn từ cộng đồng vì cách tiếp cận: không than phiền, không drama — chỉ chia sẻ kiến thức kỹ thuật sâu và bài học thật.

---

## Nguồn

- Video gốc: "I was laid off by Atlassian" — Vasilios Syrakis (YouTube, ~tháng 5/2026, 38 phút)
- GitHub: github.com/cetanu (profile) + github.com/cetanu/sovereign (mã nguồn)
- Atlassian Developer Docs: developer.atlassian.com/platform/sovereign
- Bloomberg: "Atlassian CEO Announces Layoffs of 1,600, Citing AI Shift" (11/3/2026)
- CRN: "Atlassian Plans 1,600 Layoffs With Savings Shift To AI" (3/2026)
- Computerworld: "Atlassian cuts 1,600 jobs to fund AI and enterprise expansion" (6/2026)
- Financial Express: "'I built a lot of things': Laid off engineer shares 38-minute video"
- Medium/TechX: "Software Engineer at Atlassian was laid off on March 12 after 8 years"
- Medium/GitConnected: "Atlassian Laid Him Off After 8 Years"
- IT Chronicles Substack: "A Gold Mine of Platform Engineering Wisdom"
- TheNextWeb: "Atlassian is cutting 1,600 jobs and replacing its CTO"
