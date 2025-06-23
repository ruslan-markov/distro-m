FROM archlinux:base-20250615.0.365905

ENV TERM=xterm

RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm archiso git sudo mkinitcpio-archiso grub syslinux

WORKDIR /workspace

# Копируем все файлы проекта
COPY . /workspace

# Делаем steps.sh исполняемым
RUN chmod +x steps.sh

USER root

# Запускаем сборку от root
CMD ["/workspace/steps.sh"]