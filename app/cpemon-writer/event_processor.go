package main

import (
	"context"
	"fmt"

	"github.com/huangruidtu/cpemon-mvp/app/pkg/events"
)

func processConsumedEvent(ctx context.Context, exec sqlExecutor, event events.ConsumedEvent) error {
	switch event.Topic {
	case events.DeviceHeartbeatTopic:
		return processHeartbeatConsumedEvent(ctx, exec, event)
	case events.WANStatusTopic:
		return processWANStatusConsumedEvent(ctx, exec, event)
	default:
		return fmt.Errorf("unsupported consumed event topic %q", event.Topic)
	}
}
