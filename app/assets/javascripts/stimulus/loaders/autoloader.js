import { Application } from "stimulus"

export class Autoloader {
  static get controllerAttribute() {
    return "data-controller"
  }

  static get controllersSelector() {
    return `[${this.controllerAttribute}]`
  }

  constructor() {
    this.application = Application.start()
    this.observer = new MutationObserver((mutationList) => this.observerCallback(mutationList))
  }

  async enable() {
    await this.loadControllers(Array.from(document.querySelectorAll(Autoloader.controllersSelector)))
    this.observer.observe(document.body, { attributeFilter: [Autoloader.controllerAttribute], subtree: true, childList: true })
  }

  disable() {
    this.observer.disconnect()
  }

  observerCallback(mutationList) {
    this.reloadControllers(mutationList)
  }

  async reloadControllers(mutationList) {
    const targets = mutationList
      .flatMap((record) => {
        switch (record.type) {
          case "attributes":
            if (record.attributeName === Autoloader.controllerAttribute && record.target.hasAttribute(Autoloader.controllerAttribute)) {
              return [record.target]
            } else {
              return []
            }
          case "childList":
            return Array.from(record.addedNodes).filter((node) => {
              return node.nodeType === Node.ELEMENT_NODE && node.hasAttribute(Autoloader.controllerAttribute)
            })
          default:
            return []
        }
      })
    if (targets.length > 0) {
      return await this.loadControllers(targets)
    } else {
      return []
    }
  }

  async loadControllers(elements) {
    return await Promise.allSettled(
      elements.flatMap((element) => {
        const controllerNames = element.attributes[Autoloader.controllerAttribute].value.split(" ")
        return controllerNames.map((controllerName) => this.loadController(controllerName))
      })
    ).then((values) => {
      values.filter((value) => value.status === "rejected").forEach((value) => {
        this.application.logger.error(value.reason.message, ...value.reason.errors)
      })
      return values
    })
  }

  async loadController(name) {
    try {
      const underscoredControllerName = name.replace(/--/g, "/").replace(/-/g, "_")
      const module = await import(`${underscoredControllerName}_controller`)
      this.application.register(name, module.default)
    } catch(error) {
      throw new AggregateError([error], `Failed to autoload controller: ${name}`)
    }
  }
}

const autoloader = new Autoloader()

autoloader.enable()
