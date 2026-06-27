from locust import HttpUser, task, between
import json

class FullAppLoadTest(HttpUser):
    # محاكاة وقت انتظار عشوائي بين دقيقة ودقيقتين لكل مستخدم وهمي قبل تكرار العملية
    wait_time = between(1, 3)

    @task(3)  # وزن أعلى لمحاكاة ضغط حجز طلبات وعهدة التجار
    def test_checkout_flow(self):
        url = "/createOrdersWithPromos"
        payload = {
            "data": {
                "userId": "locust_mass_user",
                "cashbackToReserve": 15.0,
                "ordersData": [
                    {
                        "sellerId": "mass_seller_test",
                        "total": 200.0,
                        "cashbackApplied": 15.0,
                        "items": [],
                        "buyer": {
                            "name": "تاجر اختبار الضغط",
                            "governorate": "الإسكندرية"
                        }
                    }
                ]
            }
        }
        headers = {"Content-Type": "application/json"}
        self.client.post(url, data=json.dumps(payload), headers=headers)

    @task(5)  # محاكاة المناديب وتحديثات المواقع اللوجستية الفورية (إدارة العهدة)
    def test_driver_location_updates(self):
        self.client.get("/getDriverLocation")