from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# محاكاة قواعد البيانات والحالات للتطبيق بالكامل
mock_orders = {}

@app.route('/createOrdersWithPromos', methods=['POST'])
def create_order():
    # محاكاة استقبال الطلب من الفلاتر وضبط الحقول لوجستياً
    req_data = request.json.get('data', {})
    user_id = req_data.get('userId')
    if not user_id:
        return jsonify({"error": {"status": "INVALID_ARGUMENT", "message": "بيانات غير مكتملة"}}), 400
    
    order_id = f"ORD_{user_id}_123"
    mock_orders[order_id] = {"status": "new-order", "data": req_data}
    print(f"📦 [سيرفر المحاكاة]: تم استلام طلب جديد وتخصيص نقاط التأمين للبروفايل: {user_id}")
    return jsonify({"result": {"success": True, "orderIds": [order_id], "cashbackDeducted": req_data.get('cashbackToReserve', 0)}})

@app.route('/getDriverLocation', methods=['GET'])
def get_driver():
    # محاكاة إحداثيات الخريطة الفورية لتطبيق المندوب والمستهلك
    return jsonify({"lat": 31.2001, "lng": 29.9187, "status": "إدارة عهدة"})

if __name__ == '__main__':
    # تشغيل السيرفر المحرك على البورت المعتمد لديك 8080 وبثه لكل الأجهزة
    app.run(host='0.0.0.0', port=5000, debug=True)