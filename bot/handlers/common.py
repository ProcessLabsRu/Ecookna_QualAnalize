from aiogram import Router, types
from aiogram.filters import Command

router = Router()

@router.message(Command("start"))
async def cmd_start(message: types.Message):
    await message.answer(
        "Привет! Я бот для анализа качества оконных конструкций.\n"
        "Пришлите мне PDF файл с заказом, и я проверю его на соответствие таблице слипаемости."
    )

@router.message(Command("help"))
async def cmd_help(message: types.Message):
    await message.answer(
        "Инструкция:\n"
        "1. Отправьте PDF файл с выгрузкой заказа.\n"
        "2. Бот обработает файл и пришлет отчет о найденных ошибках.\n"
        "3. Если ошибок нет, бот сообщит, что все в порядке."
    )
