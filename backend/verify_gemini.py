from app.services.gemini_service import gemini_service


def test_gemini_service():
    print("Testing gemini_service.py...")
    try:
        masked_key = (
            f"{gemini_service.api_key[:6]}...{gemini_service.api_key[-4:]}"
            if gemini_service.api_key
            else "not configured"
        )
        print(f"API Key: {masked_key}")

        empty_data = gemini_service._get_empty_invoice_data()
        assert "invoice_details" in empty_data
        assert "line_items" in empty_data
        print("Empty data structure: OK")

        verification = gemini_service.verify_connection()
        if verification["ok"]:
            print("API verification: OK")
            print(
                f"Available models: "
                f"{', '.join(verification['models']) or 'No models returned'}"
            )
            return 0

        print(f"API verification: FAILED - {verification['message']}")
        return 1
    except Exception as exc:
        print(f"Error during verification: {exc}")
        import traceback

        traceback.print_exc()
        return 1


if __name__ == "__main__":
    raise SystemExit(test_gemini_service())
