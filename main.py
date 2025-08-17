from fastapi import FastAPI
import os

app = FastAPI(title="Hello World API", version="1.0.0")

@app.get("/")
async def root():
    return {"message": "Hello World, Welcome to FastAPI!"}

@app.get("/health")
async def health_check():
    return {"status": "healthy"}

@app.get("/version")
async def version():
    return {"version": "1.0.1"}

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)
